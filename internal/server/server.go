package server

import (
	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/config"
	"github.com/hwview/hwview/internal/audit"
	"github.com/hwview/hwview/internal/auth"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/adapters"
	"gorm.io/gorm"
)

type Server struct {
	cfg        *config.Config
	adapterReg *adapters.Registry
	authMW     *auth.Middleware
	lineSvc    *ProductionLineService
	srcSvc     *DataSourceService
	statsSvc   *StatisticsService
	agentSvc   *AgentService
	healthSvc  *HealthService
	reportSvc  *ReportService
}

func New(cfg *config.Config, adapterReg *adapters.Registry, db *gorm.DB) *Server {
	authMW := auth.NewMiddleware(&cfg.Auth)
	lineRepo := store.NewProductionLineRepo(db)
	srcRepo := store.NewDataSourceRepo(db)
	recordRepo := store.NewProductionRecordRepo(db)
	planRepo := store.NewDailyProductionPlanRepo(db)
	auditSvc := audit.NewService(db)
	lineSvc := NewProductionLineService(lineRepo, auditSvc)
	srcSvc := NewDataSourceService(srcRepo, auditSvc)
	statsSvc := NewStatisticsService(db, recordRepo, planRepo, lineRepo, cfg.Shadow.Enabled && cfg.Shadow.StatisticsShadow, cfg.Shadow.QuantityLabel)
	agentSvc := NewAgentService(db, auditSvc)
	healthSvc := NewHealthService(db)
	reportSvc := NewReportService(db, auditSvc)
	return &Server{cfg: cfg, adapterReg: adapterReg, authMW: authMW, lineSvc: lineSvc, srcSvc: srcSvc, statsSvc: statsSvc, agentSvc: agentSvc, healthSvc: healthSvc, reportSvc: reportSvc}
}

func (s *Server) RegisterRoutes(router *gin.Engine) error {
	api := router.Group("/api/v1")
	api.GET("/health", s.healthHandler)
	api.GET("/adapters", s.listAdapters)

	api.POST("/auth/login", s.authMW.Login())
	api.GET("/auth/check", s.authMW.Check())

	s.lineSvc.RegisterRoutes(api, s.authMW.RequireAdmin())
	s.srcSvc.RegisterRoutes(api, s.authMW.RequireAdmin())
	s.statsSvc.RegisterRoutes(api)
	s.agentSvc.RegisterRoutes(api)
	s.healthSvc.RegisterRoutes(api)
	s.reportSvc.RegisterRoutes(api, s.authMW.RequireAdmin())
	return nil
}

func (s *Server) healthHandler(c *gin.Context) {
	c.JSON(200, gin.H{"status": "ok"})
}

func (s *Server) listAdapters(c *gin.Context) {
	c.JSON(200, gin.H{"adapters": s.adapterReg.List()})
}
