package store

import (
	"context"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.ProductionLine{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestProductionLineRepo_CreateFiveLines(t *testing.T) {
	db := setupTestDB(t)
	repo := NewProductionLineRepo(db)
	ctx := context.Background()

	lines := []model.ProductionLine{
		{LineCode: "HW102-COPY", LineName: "Huawei102-Copy-Line", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true, Status: model.LineStatusConfigured},
		{LineCode: "HW102-LINE", LineName: "Huawei102-LINE", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102LineAdapter", Enabled: true, Status: model.LineStatusConfigured},
		{LineCode: "BMW", LineName: "BMW", Customer: "BMW", Product: "BMW", AdapterType: "BMWAdapter", Enabled: true, Status: model.LineStatusConfigured},
		{LineCode: "SCHAEFFLER", LineName: "Schaeffler", Customer: "Schaeffler", Product: "SCHAEFFLER", AdapterType: "SchaefflerAdapter", Enabled: true, Status: model.LineStatusConfigured},
		{LineCode: "MAGNA", LineName: "Magna", Customer: "Magna", Product: "MAGNA", AdapterType: "MagnaAdapter", Enabled: true, Status: model.LineStatusConfigured},
	}

	for i, line := range lines {
		if err := repo.Create(ctx, &lines[i]); err != nil {
			t.Fatalf("Create line %s failed: %v", line.LineCode, err)
		}
	}

	all, err := repo.List(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 5 {
		t.Fatalf("expected 5 lines, got %d", len(all))
	}
	t.Logf("Successfully created %d production lines", len(all))
}

func TestProductionLineRepo_LineCodeConflict(t *testing.T) {
	db := setupTestDB(t)
	repo := NewProductionLineRepo(db)
	ctx := context.Background()

	line1 := model.ProductionLine{LineCode: "HW102-COPY", LineName: "Huawei102-Copy", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	if err := repo.Create(ctx, &line1); err != nil {
		t.Fatal(err)
	}

	line2 := model.ProductionLine{LineCode: "HW102-COPY", LineName: "duplicate", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	err := repo.Create(ctx, &line2)
	if err == nil {
		t.Fatal("expected conflict error, got nil")
	}
	t.Logf("Correctly rejected duplicate line_code: %v", err)
}

func TestProductionLineRepo_RequiredFieldEmpty(t *testing.T) {
	db := setupTestDB(t)
	repo := NewProductionLineRepo(db)
	ctx := context.Background()

	line := model.ProductionLine{LineCode: "", LineName: "test", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter"}
	err := repo.Create(ctx, &line)
	if err == nil {
		t.Fatal("expected required field error, got nil")
	}
	t.Logf("Correctly rejected empty required field: %v", err)
}

func TestProductionLineRepo_GetByCode(t *testing.T) {
	db := setupTestDB(t)
	repo := NewProductionLineRepo(db)
	ctx := context.Background()

	line := model.ProductionLine{LineCode: "HW102-COPY", LineName: "Huawei102-Copy", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	if err := repo.Create(ctx, &line); err != nil {
		t.Fatal(err)
	}

	found, err := repo.GetByCode(ctx, "HW102-COPY")
	if err != nil {
		t.Fatal(err)
	}
	if found.LineName != "Huawei102-Copy" {
		t.Fatalf("expected Huawei102-Copy, got %s", found.LineName)
	}
}