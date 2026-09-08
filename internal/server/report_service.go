package server

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/model"
	"github.com/xuri/excelize/v2"
	"gorm.io/gorm"
)

type ReportService struct {
	planRepo   *store.DailyProductionPlanRepo
	holidayRepo *store.HolidayRepo
	cartonRepo *store.CartonSpecRepo
	db         *gorm.DB
}

func NewReportService(db *gorm.DB) *ReportService {
	return &ReportService{
		planRepo:    store.NewDailyProductionPlanRepo(db),
		holidayRepo: store.NewHolidayRepo(db),
		cartonRepo:  store.NewCartonSpecRepo(db),
		db:          db,
	}
}

func (s *ReportService) RegisterRoutes(rg *gin.RouterGroup) {
	reports := rg.Group("/reports")
	{
		reports.GET("/daily-output-plan", s.getReport)
		reports.GET("/daily-output-plan/export", s.exportReport)

		reports.POST("/daily-plan", s.createPlan)
		reports.GET("/daily-plan", s.listPlans)
		reports.PUT("/daily-plan/:id", s.updatePlan)
		reports.DELETE("/daily-plan/:id", s.deletePlan)

		reports.POST("/holidays", s.createHoliday)
		reports.GET("/holidays", s.listHolidays)
		reports.PUT("/holidays/:id", s.updateHoliday)
		reports.DELETE("/holidays/:id", s.deleteHoliday)
	}

	config := rg.Group("/config")
	{
		config.POST("/carton-spec", s.createCartonSpec)
		config.GET("/carton-spec", s.listCartonSpecs)
		config.PUT("/carton-spec/:id", s.updateCartonSpec)
		config.DELETE("/carton-spec/:id", s.deleteCartonSpec)
	}
}

type planInput struct {
	PlanDate       string `json:"plan_date" binding:"required"`
	RowNo          int    `json:"row_no" binding:"required"`
	Value          *int   `json:"value,omitempty"`
	CartonCount    *int   `json:"carton_count,omitempty"`
	LooseQuantity  *int   `json:"loose_quantity,omitempty"`
	LineCode       string `json:"line_code,omitempty"`
	ProductCode    string `json:"product_code,omitempty"`
	InputBy        string `json:"input_by" binding:"required"`
}

func (s *ReportService) createPlan(c *gin.Context) {
	var input planInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	plan := &model.DailyProductionPlan{
		PlanDate:       input.PlanDate,
		RowNo:          input.RowNo,
		Value:          input.Value,
		CartonCount:    input.CartonCount,
		LooseQuantity:  input.LooseQuantity,
		LineCode:       input.LineCode,
		InputBy:        input.InputBy,
	}

	if model.CartonModeRows[input.RowNo] {
		lineCode := input.LineCode
		if lineCode == "" {
			lineCode = "HW102"
		}
		productCode := input.ProductCode
		if productCode == "" {
			productCode = "HW102"
		}
		spec, err := s.cartonRepo.FindEffective(c.Request.Context(), lineCode, productCode, input.PlanDate)
		if err != nil {
			c.JSON(http.StatusPreconditionFailed, gin.H{"error": "no effective carton specification found for line/product/date"})
			return
		}
		plan.UnitsPerCartonSnapshot = &spec.UnitsPerCarton
		if plan.CartonCount != nil && plan.LooseQuantity != nil {
			actual := *plan.CartonCount * spec.UnitsPerCarton + *plan.LooseQuantity
			plan.ActualQuantity = &actual
		}
	}

	if err := s.planRepo.Upsert(c.Request.Context(), plan); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, plan)
}

func (s *ReportService) listPlans(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	lineCode := c.Query("line_code")
	if startDate == "" || endDate == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_date and end_date are required"})
		return
	}
	plans, err := s.planRepo.ListByDateRange(c.Request.Context(), startDate, endDate, lineCode)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"plans": plans})
}

func (s *ReportService) updatePlan(c *gin.Context) {
	var input planInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	plan := &model.DailyProductionPlan{
		PlanDate:      input.PlanDate,
		RowNo:         input.RowNo,
		Value:         input.Value,
		CartonCount:   input.CartonCount,
		LooseQuantity: input.LooseQuantity,
		LineCode:      input.LineCode,
		InputBy:       input.InputBy,
	}
	if model.CartonModeRows[input.RowNo] {
		lineCode := input.LineCode
		if lineCode == "" {
			lineCode = "HW102"
		}
		productCode := input.ProductCode
		if productCode == "" {
			productCode = "HW102"
		}
		spec, err := s.cartonRepo.FindEffective(c.Request.Context(), lineCode, productCode, input.PlanDate)
		if err != nil {
			c.JSON(http.StatusPreconditionFailed, gin.H{"error": "no effective carton specification found"})
			return
		}
		plan.UnitsPerCartonSnapshot = &spec.UnitsPerCarton
		if plan.CartonCount != nil && plan.LooseQuantity != nil {
			actual := *plan.CartonCount * spec.UnitsPerCarton + *plan.LooseQuantity
			plan.ActualQuantity = &actual
		}
	}
	if err := s.planRepo.Upsert(c.Request.Context(), plan); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, plan)
}

func (s *ReportService) deletePlan(c *gin.Context) {
	var id struct {
		ID int64 `uri:"id" binding:"required"`
	}
	if err := c.ShouldBindUri(&id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := s.planRepo.Delete(c.Request.Context(), id.ID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "deleted"})
}

type holidayInput struct {
	HolidayDate string `json:"holiday_date" binding:"required"`
	HolidayName string `json:"holiday_name" binding:"required"`
	IsRest      bool   `json:"is_rest"`
	ConfigBy    string `json:"config_by" binding:"required"`
}

func (s *ReportService) createHoliday(c *gin.Context) {
	var input holidayInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	holiday := &model.HolidayCalendar{
		HolidayDate: input.HolidayDate,
		HolidayName: input.HolidayName,
		IsRest:      input.IsRest,
		ConfigBy:    input.ConfigBy,
	}
	if err := s.holidayRepo.Upsert(c.Request.Context(), holiday); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, holiday)
}

func (s *ReportService) listHolidays(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	if startDate == "" || endDate == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_date and end_date are required"})
		return
	}
	holidays, err := s.holidayRepo.ListByDateRange(c.Request.Context(), startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"holidays": holidays})
}

func (s *ReportService) updateHoliday(c *gin.Context) {
	s.createHoliday(c)
}

func (s *ReportService) deleteHoliday(c *gin.Context) {
	var id struct {
		ID int64 `uri:"id" binding:"required"`
	}
	if err := c.ShouldBindUri(&id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := s.holidayRepo.Delete(c.Request.Context(), id.ID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "deleted"})
}

type cartonSpecInput struct {
	LineCode       string  `json:"line_code" binding:"required"`
	ProductCode    string  `json:"product_code" binding:"required"`
	UnitsPerCarton int     `json:"units_per_carton" binding:"required"`
	EffectiveFrom  string  `json:"effective_from" binding:"required"`
	EffectiveTo    *string `json:"effective_to,omitempty"`
	ConfigBy       string  `json:"config_by" binding:"required"`
}

func (s *ReportService) createCartonSpec(c *gin.Context) {
	var input cartonSpecInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if input.UnitsPerCarton <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "units_per_carton must be positive"})
		return
	}
	spec := &model.CartonSpecification{
		LineCode:       input.LineCode,
		ProductCode:    input.ProductCode,
		UnitsPerCarton: input.UnitsPerCarton,
		EffectiveFrom:  input.EffectiveFrom,
		EffectiveTo:    input.EffectiveTo,
		ConfigBy:       input.ConfigBy,
	}
	if err := s.cartonRepo.Create(c.Request.Context(), spec); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, spec)
}

func (s *ReportService) listCartonSpecs(c *gin.Context) {
	specs, err := s.cartonRepo.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"specs": specs})
}

func (s *ReportService) updateCartonSpec(c *gin.Context) {
	var id struct {
		ID int64 `uri:"id" binding:"required"`
	}
	if err := c.ShouldBindUri(&id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var input cartonSpecInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	spec := &model.CartonSpecification{
		ID:             id.ID,
		LineCode:       input.LineCode,
		ProductCode:    input.ProductCode,
		UnitsPerCarton: input.UnitsPerCarton,
		EffectiveFrom:  input.EffectiveFrom,
		EffectiveTo:    input.EffectiveTo,
		ConfigBy:       input.ConfigBy,
	}
	if err := s.cartonRepo.Update(c.Request.Context(), spec); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, spec)
}

func (s *ReportService) deleteCartonSpec(c *gin.Context) {
	var id struct {
		ID int64 `uri:"id" binding:"required"`
	}
	if err := c.ShouldBindUri(&id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := s.cartonRepo.Delete(c.Request.Context(), id.ID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "deleted"})
}

type reportResponse struct {
	Title       string             `json:"title"`
	Dates       []string           `json:"dates"`
	RowNames    []string           `json:"row_names"`
	RowColors   []string           `json:"row_colors"`
	Matrix      [][]*int           `json:"matrix"`
	Cumulative  []int              `json:"cumulative"`
	Holidays    map[string]string  `json:"holidays"`
	Reference   *referenceData     `json:"reference,omitempty"`
}

type referenceData struct {
	Description string            `json:"description"`
	PerDate     map[string]map[string]int `json:"per_date"`
}

var rowNames = []string{
	"目标数量老线",
	"实际完成数量（老线白班）",
	"实际完成数量（老线夜班）",
	"目标数量新线",
	"实际完成数量（新线）",
	"合计（新老线实际完成数量）",
	"成品入库数量",
	"出货数量",
	"成品库存量",
	"产线成品剩余量",
}

var rowColors = []string{
	"green", "", "", "green", "", "blue", "", "", "blue", "",
}

func (s *ReportService) getReport(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	lineCode := c.Query("line_code")
	if startDate == "" || endDate == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_date and end_date are required"})
		return
	}

	dates := generateDates(startDate, endDate)

	plans, err := s.planRepo.ListByDateRange(c.Request.Context(), startDate, endDate, lineCode)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	holidays, err := s.holidayRepo.ListByDateRange(c.Request.Context(), startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	holidayMap := make(map[string]string)
	for _, h := range holidays {
		if h.IsRest {
			holidayMap[h.HolidayDate] = h.HolidayName
		}
	}

	planMap := make(map[string]map[int]*model.DailyProductionPlan)
	for _, p := range plans {
		if planMap[p.PlanDate] == nil {
			planMap[p.PlanDate] = make(map[int]*model.DailyProductionPlan)
		}
		planMap[p.PlanDate][p.RowNo] = &p
	}

	matrix := make([][]*int, 10)
	for i := range matrix {
		matrix[i] = make([]*int, len(dates))
	}

	cumulativeInbound := 0
	cumulativeShipment := 0

	for colIdx, date := range dates {
		datePlans := planMap[date]

		for row := 1; row <= 10; row++ {
			if row == model.RowTotalActual || row == model.RowInventory {
				continue
			}
			if datePlans[row] != nil {
				matrix[row-1][colIdx] = getPlanValue(datePlans[row])
			}
		}

		row2 := getVal(matrix[1][colIdx])
		row3 := getVal(matrix[2][colIdx])
		row5 := getVal(matrix[4][colIdx])
		total := row2 + row3 + row5
		matrix[5][colIdx] = &total

		inbound := getVal(matrix[6][colIdx])
		shipment := getVal(matrix[7][colIdx])
		cumulativeInbound += inbound
		cumulativeShipment += shipment
		inventory := cumulativeInbound - cumulativeShipment
		matrix[8][colIdx] = &inventory
	}

	cumulative := make([]int, 10)
	for row := 0; row < 10; row++ {
		sum := 0
		for col := 0; col < len(dates); col++ {
			if matrix[row][col] != nil {
				sum += *matrix[row][col]
			}
		}
		cumulative[row] = sum
	}

	ref := s.buildReference(c.Request.Context(), dates, lineCode)

	resp := reportResponse{
		Title:      "102日产出计划报表",
		Dates:      dates,
		RowNames:   rowNames,
		RowColors:  rowColors,
		Matrix:     matrix,
		Cumulative: cumulative,
		Holidays:   holidayMap,
		Reference:  ref,
	}
	c.JSON(http.StatusOK, resp)
}

func (s *ReportService) buildReference(ctx context.Context, dates []string, lineCode string) *referenceData {
	if len(dates) == 0 {
		return nil
	}
	ref := &referenceData{
		Description: "标签补打参考数据（来自TBL_PRODUCTION_RECORD，非生产数量）",
		PerDate:     make(map[string]map[string]int),
	}
	for _, date := range dates {
		var count, uniqueBc, sumQty int64
		s.db.WithContext(ctx).Model(&model.ProductionRecord{}).
			Where("production_date = ?", date).
			Count(&count)
		s.db.WithContext(ctx).Model(&model.ProductionRecord{}).
			Where("production_date = ?", date).
			Distinct("barcode").Count(&uniqueBc)
		s.db.WithContext(ctx).Model(&model.ProductionRecord{}).
			Where("production_date = ?", date).
			Select("COALESCE(SUM(quantity), 0)").Scan(&sumQty)
		if count > 0 {
			ref.PerDate[date] = map[string]int{
				"A_records":      int(count),
				"B_unique_barcodes": int(uniqueBc),
				"D_sum_quantity":   int(sumQty),
			}
		}
	}
	return ref
}

func (s *ReportService) exportReport(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	lineCode := c.Query("line_code")
	if startDate == "" || endDate == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_date and end_date are required"})
		return
	}

	dates := generateDates(startDate, endDate)
	plans, err := s.planRepo.ListByDateRange(c.Request.Context(), startDate, endDate, lineCode)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	holidays, err := s.holidayRepo.ListByDateRange(c.Request.Context(), startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	holidaySet := make(map[string]bool)
	for _, h := range holidays {
		if h.IsRest {
			holidaySet[h.HolidayDate] = true
		}
	}

	planMap := make(map[string]map[int]*model.DailyProductionPlan)
	for _, p := range plans {
		if planMap[p.PlanDate] == nil {
			planMap[p.PlanDate] = make(map[int]*model.DailyProductionPlan)
		}
		planMap[p.PlanDate][p.RowNo] = &p
	}

	matrix := make([][]*int, 10)
	for i := range matrix {
		matrix[i] = make([]*int, len(dates))
	}
	cumulativeInbound := 0
	cumulativeShipment := 0
	for colIdx, date := range dates {
		datePlans := planMap[date]
		for row := 1; row <= 10; row++ {
			if row == model.RowTotalActual || row == model.RowInventory {
				continue
			}
			if datePlans[row] != nil {
				matrix[row-1][colIdx] = getPlanValue(datePlans[row])
			}
		}
		row2 := getVal(matrix[1][colIdx])
		row3 := getVal(matrix[2][colIdx])
		row5 := getVal(matrix[4][colIdx])
		total := row2 + row3 + row5
		matrix[5][colIdx] = &total
		inbound := getVal(matrix[6][colIdx])
		shipment := getVal(matrix[7][colIdx])
		cumulativeInbound += inbound
		cumulativeShipment += shipment
		inventory := cumulativeInbound - cumulativeShipment
		matrix[8][colIdx] = &inventory
	}

	f := excelize.NewFile()
	sheet := "102日产出计划"
	f.SetSheetName(f.GetSheetName(0), sheet)

	greenStyle, _ := f.NewStyle(&excelize.Style{Fill: excelize.Fill{Type: "pattern", Color: []string{"#90EE90"}, Pattern: 1}})
	blueStyle, _ := f.NewStyle(&excelize.Style{Fill: excelize.Fill{Type: "pattern", Color: []string{"#ADD8E6"}, Pattern: 1}})
	yellowStyle, _ := f.NewStyle(&excelize.Style{Fill: excelize.Fill{Type: "pattern", Color: []string{"#FFFFE0"}, Pattern: 1}})

	f.SetCellValue(sheet, "A1", "102日产出计划")
	axis, _ := excelize.CoordinatesToCellName(2, 1)
	f.SetCellValue(sheet, axis, "累计数量")

	for colIdx, date := range dates {
		cell, _ := excelize.CoordinatesToCellName(colIdx+2, 1)
		f.SetCellValue(sheet, cell, date)
	}

	for rowIdx, name := range rowNames {
		cell, _ := excelize.CoordinatesToCellName(1, rowIdx+2)
		f.SetCellValue(sheet, cell, name)
		if rowColors[rowIdx] == "green" {
			f.SetCellStyle(sheet, cell, cell, greenStyle)
		} else if rowColors[rowIdx] == "blue" {
			f.SetCellStyle(sheet, cell, cell, blueStyle)
		}
		for colIdx := range dates {
			cell, _ := excelize.CoordinatesToCellName(colIdx+2, rowIdx+2)
			if matrix[rowIdx][colIdx] != nil {
				f.SetCellValue(sheet, cell, *matrix[rowIdx][colIdx])
			}
			if holidaySet[dates[colIdx]] {
				f.SetCellStyle(sheet, cell, cell, yellowStyle)
			}
			if rowColors[rowIdx] == "green" {
				f.SetCellStyle(sheet, cell, cell, greenStyle)
			} else if rowColors[rowIdx] == "blue" {
				f.SetCellStyle(sheet, cell, cell, blueStyle)
			}
		}
		cumCell, _ := excelize.CoordinatesToCellName(len(dates)+2, rowIdx+2)
		sum := 0
		for col := range dates {
			if matrix[rowIdx][col] != nil {
				sum += *matrix[rowIdx][col]
			}
		}
		f.SetCellValue(sheet, cumCell, sum)
	}

	filename := fmt.Sprintf("102_daily_output_plan_%s_to_%s.xlsx", startDate, endDate)
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	if err := f.Write(c.Writer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
}

func generateDates(start, end string) []string {
	var dates []string
	t, err := time.Parse("2006-01-02", start)
	if err != nil {
		return dates
	}
	endT, err := time.Parse("2006-01-02", end)
	if err != nil {
		return dates
	}
	for !t.After(endT) {
		dates = append(dates, t.Format("2006-01-02"))
		t = t.AddDate(0, 0, 1)
	}
	return dates
}

func getPlanValue(plan *model.DailyProductionPlan) *int {
	if plan.Value != nil {
		return plan.Value
	}
	if plan.ActualQuantity != nil {
		return plan.ActualQuantity
	}
	return nil
}

func getVal(p *int) int {
	if p == nil {
		return 0
	}
	return *p
}