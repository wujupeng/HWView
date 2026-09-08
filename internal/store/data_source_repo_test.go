package store

import (
	"context"
	"testing"

	"github.com/hwview/hwview/pkg/model"
)

func TestDataSourceRepo_CreateAndIPUpdate(t *testing.T) {
	db := setupTestDB(t)
	if err := db.AutoMigrate(&model.DataSource{}); err != nil {
		t.Fatal(err)
	}
	lineRepo := NewProductionLineRepo(db)
	srcRepo := NewDataSourceRepo(db)
	ctx := context.Background()

	line := model.ProductionLine{LineCode: "HW102-COPY", LineName: "华为102复制线", Customer: "华为", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	if err := lineRepo.Create(ctx, &line); err != nil {
		t.Fatal(err)
	}

	src := model.DataSource{LineID: line.ID, Hostname: "xiai-PC", CurrentIP: "192.168.30.2", Port: 86, BasePath: "/Cron/Jili/lists/", Enabled: true}
	if err := srcRepo.Create(ctx, &src); err != nil {
		t.Fatal(err)
	}
	t.Logf("Created source: id=%d, ip=%s", src.ID, src.CurrentIP)

	if err := srcRepo.UpdateCurrentIP(ctx, src.ID, "192.168.30.27"); err != nil {
		t.Fatal(err)
	}

	updated, err := srcRepo.GetByID(ctx, src.ID)
	if err != nil {
		t.Fatal(err)
	}
	if updated.CurrentIP != "192.168.30.27" {
		t.Fatalf("expected IP 192.168.30.27, got %s", updated.CurrentIP)
	}
	t.Logf("IP updated: %s -> %s (DHCP switch simulated)", "192.168.30.2", updated.CurrentIP)
}

func TestDataSourceRepo_ListByLine(t *testing.T) {
	db := setupTestDB(t)
	if err := db.AutoMigrate(&model.DataSource{}); err != nil {
		t.Fatal(err)
	}
	lineRepo := NewProductionLineRepo(db)
	srcRepo := NewDataSourceRepo(db)
	ctx := context.Background()

	line := model.ProductionLine{LineCode: "BMW", LineName: "BMW", Customer: "BMW", Product: "BMW", AdapterType: "BMWAdapter", Enabled: true}
	if err := lineRepo.Create(ctx, &line); err != nil {
		t.Fatal(err)
	}

	src := model.DataSource{LineID: line.ID, CurrentIP: "10.0.0.5", Port: 80, BasePath: "/api/records", Enabled: true}
	if err := srcRepo.Create(ctx, &src); err != nil {
		t.Fatal(err)
	}

	sources, err := srcRepo.ListByLine(ctx, line.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(sources) != 1 {
		t.Fatalf("expected 1 source, got %d", len(sources))
	}
}
