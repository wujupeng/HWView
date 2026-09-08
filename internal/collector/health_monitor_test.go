package collector

import (
	"context"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/hwview/hwview/pkg/adapters"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

func setupCollectorTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(
		&model.ProductionLine{}, &model.DataSource{}, &model.ProductionRecord{},
		&model.CollectCursor{}, &model.DataSourceHealth{},
	); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestHealthMonitor_StateMachine(t *testing.T) {
	db := setupCollectorTestDB(t)
	hm := NewHealthMonitor(db, 3, 5)
	ctx := context.Background()

	src := model.DataSource{LineID: 1, CurrentIP: "192.168.30.2", Port: 86, BasePath: "/test", Enabled: true}
	db.Create(&src)

	for i := 0; i < 3; i++ {
		if err := hm.RecordFailure(ctx, src.ID, "connection refused"); err != nil {
			t.Fatal(err)
		}
	}
	health, _ := hm.GetStatus(ctx, src.ID)
	t.Logf("After 3 failures: status=%s, consecutive=%d", health.Status, health.ConsecutiveFailures)
	if health.Status != model.SourceStatusDegraded {
		t.Errorf("expected DEGRADED, got %s", health.Status)
	}

	for i := 0; i < 2; i++ {
		if err := hm.RecordFailure(ctx, src.ID, "timeout"); err != nil {
			t.Fatal(err)
		}
	}
	health, _ = hm.GetStatus(ctx, src.ID)
	t.Logf("After 5 failures: status=%s, consecutive=%d", health.Status, health.ConsecutiveFailures)
	if health.Status != model.SourceStatusOffline {
		t.Errorf("expected OFFLINE, got %s", health.Status)
	}

	if err := hm.RecordSuccess(ctx, src.ID); err != nil {
		t.Fatal(err)
	}
	health, _ = hm.GetStatus(ctx, src.ID)
	t.Logf("After success: status=%s, consecutive=%d", health.Status, health.ConsecutiveFailures)
	if health.Status != model.SourceStatusOnline {
		t.Errorf("expected ONLINE, got %s", health.Status)
	}
	if health.ConsecutiveFailures != 0 {
		t.Errorf("expected 0 failures, got %d", health.ConsecutiveFailures)
	}
}

func TestSourceResolver_BuildURL(t *testing.T) {
	db := setupCollectorTestDB(t)
	reg := adapters.NewRegistry()
	resolver := NewSourceResolver(db, reg)

	src := model.DataSource{CurrentIP: "192.168.30.27", Port: 86, BasePath: "/Cron/Jili/lists/"}
	url := resolver.BuildSourceURL(src)
	expected := "http://192.168.30.27:86/Cron/Jili/lists/"
	if url != expected {
		t.Fatalf("expected %s, got %s", expected, url)
	}
	t.Logf("Source URL: %s (IP dynamically injected, no hardcode)", url)
}
