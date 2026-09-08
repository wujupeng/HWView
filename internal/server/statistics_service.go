package server

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type StatisticsService struct {
	db            *gorm.DB
	recordRepo    *store.ProductionRecordRepo
	planRepo      *store.DailyProductionPlanRepo
	lineRepo      *store.ProductionLineRepo
	shadow        bool
	quantityLabel string
}

func NewStatisticsService(db *gorm.DB, recordRepo *store.ProductionRecordRepo, planRepo *store.DailyProductionPlanRepo, lineRepo *store.ProductionLineRepo, shadow bool, quantityLabel string) *StatisticsService {
	return &StatisticsService{db: db, recordRepo: recordRepo, planRepo: planRepo, lineRepo: lineRepo, shadow: shadow, quantityLabel: quantityLabel}
}

type DailyStatsResponse struct {
	LineID            int64  `json:"line_id"`
	LineCode          string `json:"line_code"`
	LineName          string `json:"line_name"`
	ProductionDate    string `json:"production_date"`
	BoxCount          int64  `json:"box_count"`
	PieceCount        int64  `json:"piece_count"`
	BatchCount        int64  `json:"batch_count"`
	FirstProductionAt string `json:"first_production_at"`
	LastProductionAt  string `json:"last_production_at"`
	ShadowMode        bool   `json:"shadow_mode"`
	QuantityLabel     string `json:"quantity_label"`
}

type OverviewStatsResponse struct {
	TotalPieceCount int64                `json:"total_piece_count"`
	TotalBoxCount   int64                `json:"total_box_count"`
	OnlineLineCount int64                `json:"online_line_count"`
	TotalLineCount  int64                `json:"total_line_count"`
	ShadowMode      bool                 `json:"shadow_mode"`
	QuantityLabel   string               `json:"quantity_label"`
	Lines           []DailyStatsResponse `json:"lines"`
}

func (s *StatisticsService) GetLineStats(ctx context.Context, lineCode, date string) (*DailyStatsResponse, error) {
	line, err := s.lineRepo.GetByCode(ctx, lineCode)
	if err != nil {
		return nil, err
	}
	return s.computeLineStats(ctx, line, date)
}

func (s *StatisticsService) GetOverviewStats(ctx context.Context, date string) (*OverviewStatsResponse, error) {
	lines, err := s.lineRepo.List(ctx)
	if err != nil {
		return nil, err
	}
	resp := &OverviewStatsResponse{TotalLineCount: int64(len(lines)), ShadowMode: s.shadow, QuantityLabel: s.quantityLabel}
	for _, line := range lines {
		stats, err := s.computeLineStats(ctx, &line, date)
		if err != nil {
			continue
		}
		resp.Lines = append(resp.Lines, *stats)
		resp.TotalBoxCount += stats.BoxCount
		resp.TotalPieceCount += stats.PieceCount
		if stats.BoxCount > 0 || stats.PieceCount > 0 {
			resp.OnlineLineCount++
		}
	}
	return resp, nil
}

func (s *StatisticsService) computeLineStats(ctx context.Context, line *model.ProductionLine, date string) (*DailyStatsResponse, error) {
	boxCount, err := s.planRepo.SumCartonCountByDateAndLine(ctx, date, line.LineCode)
	if err != nil {
		return nil, err
	}
	pieceCount, err := s.planRepo.SumActualQuantityByDateAndLine(ctx, date, line.LineCode)
	if err != nil {
		return nil, err
	}
	batchCount, err := s.recordRepo.CountDistinctBatchByLineAndDate(ctx, line.ID, date)
	if err != nil {
		return nil, err
	}

	var firstAt, lastAt sql.NullTime
	s.db.WithContext(ctx).Model(&model.ProductionRecord{}).
		Where("line_id = ? AND production_date = ?", line.ID, date).
		Select("MIN(created_at)").Scan(&firstAt)
	s.db.WithContext(ctx).Model(&model.ProductionRecord{}).
		Where("line_id = ? AND production_date = ?", line.ID, date).
		Select("MAX(created_at)").Scan(&lastAt)

	firstStr, lastStr := "", ""
	if firstAt.Valid {
		firstStr = firstAt.Time.Format("2006-01-02 15:04:05")
	}
	if lastAt.Valid {
		lastStr = lastAt.Time.Format("2006-01-02 15:04:05")
	}

	return &DailyStatsResponse{
		LineID:            line.ID,
		LineCode:          line.LineCode,
		LineName:          line.LineName,
		ProductionDate:    date,
		BoxCount:          boxCount,
		PieceCount:        pieceCount,
		BatchCount:        batchCount,
		FirstProductionAt: firstStr,
		LastProductionAt:  lastStr,
		ShadowMode:        s.shadow,
		QuantityLabel:     s.quantityLabel,
	}, nil
}

func (s *StatisticsService) RegisterRoutes(rg *gin.RouterGroup) {
	stats := rg.Group("/statistics")
	stats.GET("/overview", s.overviewHandler)
	stats.GET("/lines/:lineCode", s.lineStatsHandler)
}

func (s *StatisticsService) overviewHandler(c *gin.Context) {
	date := c.Query("date")
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	resp, err := s.GetOverviewStats(c.Request.Context(), date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (s *StatisticsService) lineStatsHandler(c *gin.Context) {
	lineCode := c.Param("lineCode")
	date := c.Query("date")
	if date == "" {
		date = time.Now().Format("2006-01-02")
	}
	resp, err := s.GetLineStats(c.Request.Context(), lineCode, date)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "line not found"})
		return
	}
	c.JSON(http.StatusOK, resp)
}
