package store

import (
	"context"
	"errors"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var (
	ErrHolidayNotFound = errors.New("holiday not found")
)

type HolidayRepo struct {
	db *gorm.DB
}

func NewHolidayRepo(db *gorm.DB) *HolidayRepo {
	return &HolidayRepo{db: db}
}

func (r *HolidayRepo) Upsert(ctx context.Context, holiday *model.HolidayCalendar) error {
	var existing model.HolidayCalendar
	err := r.db.WithContext(ctx).
		Where("holiday_date = ?", holiday.HolidayDate).
		First(&existing).Error
	if err == nil {
		holiday.ID = existing.ID
		holiday.ConfigAt = existing.ConfigAt
		return r.db.WithContext(ctx).Save(holiday).Error
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return r.db.WithContext(ctx).Create(holiday).Error
}

func (r *HolidayRepo) GetByDate(ctx context.Context, date string) (*model.HolidayCalendar, error) {
	var holiday model.HolidayCalendar
	err := r.db.WithContext(ctx).Where("holiday_date = ?", date).First(&holiday).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrHolidayNotFound
		}
		return nil, err
	}
	return &holiday, nil
}

func (r *HolidayRepo) ListByDateRange(ctx context.Context, startDate, endDate string) ([]model.HolidayCalendar, error) {
	var holidays []model.HolidayCalendar
	err := r.db.WithContext(ctx).
		Where("holiday_date >= ? AND holiday_date <= ?", startDate, endDate).
		Order("holiday_date ASC").
		Find(&holidays).Error
	return holidays, err
}

func (r *HolidayRepo) Delete(ctx context.Context, id int64) error {
	result := r.db.WithContext(ctx).Delete(&model.HolidayCalendar{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrHolidayNotFound
	}
	return nil
}
