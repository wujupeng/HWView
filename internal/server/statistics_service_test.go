package server

import (
	"context"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

func setupStatsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(
		&model.ProductionLine{},
		&model.ProductionRecord{},
		&model.DailyProductionPlan{},
		&model.CartonSpecification{},
	); err != nil {
		t.Fatal(err)
	}
	return db
}

func createTestLine(db *gorm.DB, lineCode, lineName string) *model.ProductionLine {
	line := model.ProductionLine{
		LineCode:    lineCode,
		LineName:    lineName,
		Customer:    "Huawei",
		Product:     "HW102",
		AdapterType: "Huawei102Adapter",
		Enabled:     true,
		Status:      model.LineStatusConfigured,
	}
	db.Create(&line)
	return &line
}

func createTestPlan(db *gorm.DB, planDate string, rowNo int, lineCode string, cartonCount, unitsPerCarton, looseQty, actualQty int, inputBy string) {
	plan := model.DailyProductionPlan{
		PlanDate:               planDate,
		RowNo:                  rowNo,
		LineCode:               lineCode,
		CartonCount:            &cartonCount,
		UnitsPerCartonSnapshot: &unitsPerCarton,
		LooseQuantity:          &looseQty,
		ActualQuantity:         &actualQty,
		InputBy:                inputBy,
	}
	db.Create(&plan)
}

func createTestPlanNullActual(db *gorm.DB, planDate string, rowNo int, lineCode string, cartonCount, unitsPerCarton int, inputBy string) {
	plan := model.DailyProductionPlan{
		PlanDate:               planDate,
		RowNo:                  rowNo,
		LineCode:               lineCode,
		CartonCount:            &cartonCount,
		UnitsPerCartonSnapshot: &unitsPerCarton,
		ActualQuantity:         nil,
		InputBy:                inputBy,
	}
	db.Create(&plan)
}

func createTestRecord(db *gorm.DB, lineID int64, sourceID, date string, quantity int) {
	rec := model.ProductionRecord{
		LineID:         lineID,
		SourceID:       sourceID,
		ProductCode:    "HW102",
		Barcode:        "BC-" + sourceID,
		BatchNo:        "BATCH-001",
		Quantity:       quantity,
		CreatedAt:      time.Now(),
		ProductionDate: date,
	}
	db.Create(&rec)
}

func newStatsService(db *gorm.DB) *StatisticsService {
	recordRepo := store.NewProductionRecordRepo(db)
	planRepo := store.NewDailyProductionPlanRepo(db)
	lineRepo := store.NewProductionLineRepo(db)
	return NewStatisticsService(db, recordRepo, planRepo, lineRepo, false, "quantity")
}

func TestDashboardBoxCountFromPlan(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 10, 30, 0, 300, "operator-A")
	createTestPlan(db, "2026-09-07", model.RowActualOldNight, "HW102", 7, 30, 9, 219, "operator-B")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	expectedBox := int64(17)
	if resp.TotalBoxCount != expectedBox {
		t.Errorf("BoxCount: expected %d (SUM(carton_count) from TBL_DAILY_PRODUCTION_PLAN), got %d", expectedBox, resp.TotalBoxCount)
	}
	t.Logf("PASS: BoxCount=%d (from SUM(carton_count) of 10+7)", resp.TotalBoxCount)
}

func TestDashboardPieceCountFromPlan(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 10, 30, 0, 300, "operator-A")
	createTestPlan(db, "2026-09-07", model.RowActualOldNight, "HW102", 7, 30, 9, 219, "operator-B")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	expectedPiece := int64(519)
	if resp.TotalPieceCount != expectedPiece {
		t.Errorf("PieceCount: expected %d (SUM(actual_quantity) from TBL_DAILY_PRODUCTION_PLAN), got %d", expectedPiece, resp.TotalPieceCount)
	}
	t.Logf("PASS: PieceCount=%d (from SUM(actual_quantity) of 300+219)", resp.TotalPieceCount)
}

func TestDashboardActualQuantityNullExcluded(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 10, 30, 0, 300, "operator-A")
	createTestPlanNullActual(db, "2026-09-07", model.RowActualOldNight, "HW102", 7, 30, "operator-B")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	if resp.TotalBoxCount != 10 {
		t.Errorf("BoxCount: expected 10 (NULL actual_quantity row excluded), got %d", resp.TotalBoxCount)
	}
	if resp.TotalPieceCount != 300 {
		t.Errorf("PieceCount: expected 300 (NULL actual_quantity row excluded), got %d", resp.TotalPieceCount)
	}
	t.Logf("PASS: BoxCount=%d, PieceCount=%d (NULL actual_quantity row correctly excluded)", resp.TotalBoxCount, resp.TotalPieceCount)
}

func TestDashboardMultiplePlansSameDay(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 5, 30, 0, 150, "operator-A")
	createTestPlan(db, "2026-09-07", model.RowActualOldNight, "HW102", 3, 30, 0, 90, "operator-B")
	createTestPlan(db, "2026-09-07", model.RowActualNewLine, "HW102", 9, 30, 9, 279, "operator-C")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	expectedBox := int64(17)
	expectedPiece := int64(519)
	if resp.TotalBoxCount != expectedBox {
		t.Errorf("BoxCount: expected %d (5+3+9), got %d", expectedBox, resp.TotalBoxCount)
	}
	if resp.TotalPieceCount != expectedPiece {
		t.Errorf("PieceCount: expected %d (150+90+279), got %d", expectedPiece, resp.TotalPieceCount)
	}
	t.Logf("PASS: Multiple plans same day: BoxCount=%d (5+3+9), PieceCount=%d (150+90+279)", resp.TotalBoxCount, resp.TotalPieceCount)
}

func TestDashboardNoProductionRecordPollution(t *testing.T) {
	db := setupStatsTestDB(t)
	line := createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 10, 30, 0, 300, "operator-A")
	createTestPlan(db, "2026-09-07", model.RowActualOldNight, "HW102", 7, 30, 9, 219, "operator-B")

	for i := 0; i < 505; i++ {
		createTestRecord(db, line.ID, "rec-"+string(rune(i)), "2026-09-07", 17)
	}

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	if resp.TotalBoxCount != 17 {
		t.Errorf("BoxCount polluted by TBL_PRODUCTION_RECORD: expected 17, got %d (505 records should NOT contribute)", resp.TotalBoxCount)
	}
	if resp.TotalPieceCount != 519 {
		t.Errorf("PieceCount polluted by TBL_PRODUCTION_RECORD: expected 519, got %d (SUM(quantity)=10970 should NOT contribute)", resp.TotalPieceCount)
	}
	t.Logf("PASS: Dashboard NOT polluted by TBL_PRODUCTION_RECORD: BoxCount=%d (not 505), PieceCount=%d (not 10970)", resp.TotalBoxCount, resp.TotalPieceCount)
}

func TestDashboardEmptyDate(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", 17, 30, 9, 519, "operator-A")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-12-31")
	if err != nil {
		t.Fatal(err)
	}

	if resp.TotalBoxCount != 0 {
		t.Errorf("Empty date BoxCount: expected 0, got %d", resp.TotalBoxCount)
	}
	if resp.TotalPieceCount != 0 {
		t.Errorf("Empty date PieceCount: expected 0, got %d", resp.TotalPieceCount)
	}
	t.Logf("PASS: Empty date returns BoxCount=0, PieceCount=0")
}

func TestDashboardCartonCountActualQuantityConsistency(t *testing.T) {
	db := setupStatsTestDB(t)
	createTestLine(db, "HW102", "Huawei102")

	cartonCount := 17
	unitsPerCarton := 30
	looseQty := 9
	actualQty := cartonCount*unitsPerCarton + looseQty

	createTestPlan(db, "2026-09-07", model.RowActualOldDay, "HW102", cartonCount, unitsPerCarton, looseQty, actualQty, "operator-A")

	svc := newStatsService(db)
	resp, err := svc.GetOverviewStats(context.Background(), "2026-09-07")
	if err != nil {
		t.Fatal(err)
	}

	expectedActual := int64(cartonCount*unitsPerCarton + looseQty)
	if resp.TotalPieceCount != expectedActual {
		t.Errorf("Data lineage broken: expected actual_quantity=%d (%d*%d+%d), got %d",
			expectedActual, cartonCount, unitsPerCarton, looseQty, resp.TotalPieceCount)
	}
	if resp.TotalBoxCount != int64(cartonCount) {
		t.Errorf("BoxCount mismatch: expected %d, got %d", cartonCount, resp.TotalBoxCount)
	}
	t.Logf("PASS: Data lineage consistent: BoxCount=%d, PieceCount=%d (%d*%d+%d=%d)",
		resp.TotalBoxCount, resp.TotalPieceCount, cartonCount, unitsPerCarton, looseQty, expectedActual)
}
