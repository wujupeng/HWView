package store

import (
	"context"
	"errors"
	"time"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var (
	ErrPlanNotFound         = errors.New("daily production plan not found")
	ErrAutoCalcRowForbidden = errors.New("auto-calc row (6 or 9) cannot be manually entered")
	ErrActualQuantityInput  = errors.New("actual_quantity must not be provided in input; it is auto-calculated")
)

type DailyProductionPlanRepo struct {
	db *gorm.DB
}

func NewDailyProductionPlanRepo(db *gorm.DB) *DailyProductionPlanRepo {
	return &DailyProductionPlanRepo{db: db}
}

func (r *DailyProductionPlanRepo) Upsert(ctx context.Context, plan *model.DailyProductionPlan) error {
	if model.AutoCalcRows[plan.RowNo] {
		return ErrAutoCalcRowForbidden
	}

	if plan.LineCode == "" {
		plan.LineCode = "HW102"
	}
	now := time.Now()
	plan.UpdatedAt = now

	var existing model.DailyProductionPlan
	err := r.db.WithContext(ctx).
		Where("plan_date = ? AND row_no = ? AND line_code = ?", plan.PlanDate, plan.RowNo, plan.LineCode).
		First(&existing).Error
	if err == nil {
		plan.ID = existing.ID
		plan.InputAt = existing.InputAt
		return r.db.WithContext(ctx).Save(plan).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	plan.InputAt = now
	return r.db.WithContext(ctx).Create(plan).Error
}

func (r *DailyProductionPlanRepo) GetByDateAndRow(ctx context.Context, planDate string, rowNo int, lineCode string) (*model.DailyProductionPlan, error) {
	var plan model.DailyProductionPlan
	if lineCode == "" {
		lineCode = "HW102"
	}
	err := r.db.WithContext(ctx).
		Where("plan_date = ? AND row_no = ? AND line_code = ?", planDate, rowNo, lineCode).
		First(&plan).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPlanNotFound
		}
		return nil, err
	}
	return &plan, nil
}

func (r *DailyProductionPlanRepo) ListByDateRange(ctx context.Context, startDate, endDate, lineCode string) ([]model.DailyProductionPlan, error) {
	if lineCode == "" {
		lineCode = "HW102"
	}
	var plans []model.DailyProductionPlan
	err := r.db.WithContext(ctx).
		Where("DATE(plan_date) >= ? AND DATE(plan_date) <= ? AND line_code = ?", startDate, endDate, lineCode).
		Order("plan_date ASC, row_no ASC").
		Find(&plans).Error
	return plans, err
}

func (r *DailyProductionPlanRepo) Delete(ctx context.Context, id int64) error {
	result := r.db.WithContext(ctx).Delete(&model.DailyProductionPlan{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrPlanNotFound
	}
	return nil
}
