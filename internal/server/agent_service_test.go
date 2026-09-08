package server

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/internal/audit"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

func setupAgentTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&model.Agent{}, &model.DataSource{}, &model.ProductionLine{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestAgentService_Heartbeat(t *testing.T) {
	db := setupAgentTestDB(t)
	agentSvc := NewAgentService(db, audit.NewService(db))
	gin.SetMode(gin.TestMode)
	router := gin.New()
	agentSvc.RegisterRoutes(router.Group("/api/v1"))

	reqBody := HeartbeatRequest{
		AgentID:   "agent-001",
		Hostname:  "xiai-PC",
		MachineID: "MACHINE-XIAI-001",
		MAC:       "AA:BB:CC:DD:EE:FF",
		IPv4:      "192.168.30.2",
	}
	body, _ := json.Marshal(reqBody)
	req := httptest.NewRequest("POST", "/api/v1/agent/heartbeat", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var agent model.Agent
	db.Where("agent_id = ?", "agent-001").First(&agent)
	t.Logf("Agent registered: id=%s, host=%s, ip=%s, status=%s", agent.AgentID, agent.Hostname, agent.IPv4, agent.Status)
	if agent.Hostname != "xiai-PC" {
		t.Errorf("expected hostname xiai-PC, got %s", agent.Hostname)
	}
}

func TestAgentService_IPChanged(t *testing.T) {
	db := setupAgentTestDB(t)
	agentSvc := NewAgentService(db, audit.NewService(db))

	line := model.ProductionLine{LineCode: "HW102-COPY", LineName: "Huawei102", Customer: "Huawei", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	db.Create(&line)
	src := model.DataSource{LineID: line.ID, AgentID: "agent-001", CurrentIP: "192.168.30.2", Port: 86, BasePath: "/Cron/Jili/lists/", Enabled: true}
	db.Create(&src)

	gin.SetMode(gin.TestMode)
	router := gin.New()
	agentSvc.RegisterRoutes(router.Group("/api/v1"))

	reqBody := IPChangedRequest{
		AgentID: "agent-001",
		OldIP:   "192.168.30.2",
		NewIP:   "192.168.30.27",
	}
	body, _ := json.Marshal(reqBody)
	req := httptest.NewRequest("POST", "/api/v1/agent/ip_changed", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var updated model.DataSource
	db.First(&updated, src.ID)
	t.Logf("IP changed: %s -> %s (DHCP switch, Collector auto-reconnect)", "192.168.30.2", updated.CurrentIP)
	if updated.CurrentIP != "192.168.30.27" {
		t.Errorf("expected IP 192.168.30.27, got %s", updated.CurrentIP)
	}
	if updated.Status != model.SourceStatusSwitching {
		t.Errorf("expected status SWITCHING, got %s", updated.Status)
	}
}