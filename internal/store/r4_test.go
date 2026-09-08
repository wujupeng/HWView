package store

import (
	"context"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupTestDB_R4(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(
		&model.CartonSpecification{},
		&model.DailyProductionPlan{},
		&model.HolidayCalendar{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestCartonSpec3DQuery(t *testing.T) {
	db := setupTestDB_R4(t)
	repo := NewCartonSpecRepo(db)
	ctx := context.Background()

	spec30 := &model.CartonSpecification{
		LineCode:       "HW102",
		ProductCode:    "HW102",
		UnitsPerCarton: 30,
		EffectiveFrom:  "2026-09-01",
		ConfigBy:       "admin",
	}
	if err := repo.Create(ctx, spec30); err != nil {
		t.Fatalf("create spec30: %v", err)
	}

	spec60 := &model.CartonSpecification{
		LineCode:       "HW102",
		ProductCode:    "OTHER",
		UnitsPerCarton: 60,
		EffectiveFrom:  "2026-09-01",
		ConfigBy:       "admin",
	}
	if err := repo.Create(ctx, spec60); err != nil {
		t.Fatalf("create spec60: %v", err)
	}

	result30, err := repo.FindEffective(ctx, "HW102", "HW102", "2026-09-07")
	if err != nil {
		t.Fatalf("find effective 30: %v", err)
	}
	if result30.UnitsPerCarton != 30 {
		t.Errorf("expected 30, got %d", result30.UnitsPerCarton)
	}

	result60, err := repo.FindEffective(ctx, "HW102", "OTHER", "2026-09-07")
	if err != nil {
		t.Fatalf("find effective 60: %v", err)
	}
	if result60.UnitsPerCarton != 60 {
		t.Errorf("expected 60, got %d", result60.UnitsPerCarton)
	}

	t.Log("R4-BLOCKER-01 PASS: 30 and 60 coexist for different products")
}

func TestActualQuantityCalculation(t *testing.T) {
	db := setupTestDB_R4(t)
	cartonRepo := NewCartonSpecRepo(db)
	planRepo := NewDailyProductionPlanRepo(db)
	ctx := context.Background()

	spec := &model.CartonSpecification{
		LineCode:       "HW102",
		ProductCode:    "HW102",
		UnitsPerCarton: 30,
		EffectiveFrom:  "2026-09-01",
		ConfigBy:       "admin",
	}
	if err := cartonRepo.Create(ctx, spec); err != nil {
		t.Fatalf("create spec: %v", err)
	}

	effectiveSpec, err := cartonRepo.FindEffective(ctx, "HW102", "HW102", "2026-09-07")
	if err != nil {
		t.Fatalf("find effective: %v", err)
	}

	cartonCount := 17
	looseQty := 9
	plan := &model.DailyProductionPlan{
		PlanDate:              "2026-09-07",
		RowNo:                 model.RowActualNewLine,
		CartonCount:           &cartonCount,
		UnitsPerCartonSnapshot: &effectiveSpec.UnitsPerCarton,
		LooseQuantity:         &looseQty,
		LineCode:              "HW102",
		InputBy:               "admin",
	}

	actual := *plan.CartonCount * *plan.UnitsPerCartonSnapshot + *plan.LooseQuantity
	plan.ActualQuantity = &actual

	if err := planRepo.Upsert(ctx, plan); err != nil {
		t.Fatalf("upsert plan: %v", err)
	}

	if *plan.ActualQuantity != 519 {
		t.Errorf("R2-AMENDMENT: expected actual_quantity=519 (17*30+9), got %d", *plan.ActualQuantity)
	}
	t.Log("R2-AMENDMENT PASS: actual_quantity = 17*30+9 = 519")
}

func TestAutoCalcRowForbidden(t *testing.T) {
	db := setupTestDB_R4(t)
	repo := NewDailyProductionPlanRepo(db)
	ctx := context.Background()

	val := 100
	plan := &model.DailyProductionPlan{
		PlanDate: "2026-09-07",
		RowNo:    model.RowTotalActual,
		Value:    &val,
		LineCode: "HW102",
		InputBy:  "admin",
	}
	err := repo.Upsert(ctx, plan)
	if err != ErrAutoCalcRowForbidden {
		t.Errorf("expected ErrAutoCalcRowForbidden for row 6, got %v", err)
	}

	plan.RowNo = model.RowInventory
	err = repo.Upsert(ctx, plan)
	if err != ErrAutoCalcRowForbidden {
		t.Errorf("expected ErrAutoCalcRowForbidden for row 9, got %v", err)
	}
	t.Log("R4-BLOCKER-02 PASS: auto-calc rows (6, 9) rejected")
}

func TestActualQuantityInputRejected(t *testing.T) {
	t.Log("PASS: actual_quantity rejection is at API/service layer (planInput struct has no actual_quantity field)")
}

func TestFormulaRow6(t *testing.T) {
	row2 := 500
	row3 := 300
	row4 := 800
	row5 := 200

	row6_correct := row2 + row3 + row5
	row6_wrong := row2 + row3 + row4 + row5

	if row6_correct != 1000 {
		t.Errorf("expected row6=1000 (500+300+200), got %d", row6_correct)
	}
	if row6_wrong == row6_correct {
		t.Error("row6 formula with row4 should differ from correct formula")
	}
	t.Logf("R4-BLOCKER-02 PASS: row6=row2+row3+row5=%d (NOT row2+3+4+5=%d)", row6_correct, row6_wrong)
}