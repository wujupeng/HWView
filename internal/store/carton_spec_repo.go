package store

import (
	"context"
	"errors"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var (
	ErrCartonSpecNotFound  = errors.New("carton specification not found")
	ErrCartonSpecConflict  = errors.New("carton specification conflict: line_code + product_code + effective_from already exists")
	ErrCartonSpecInUse     = errors.New("carton specification is in use by existing production plan records")
)

type CartonSpecRepo struct {
	db *gorm.DB
}

func NewCartonSpecRepo(db *gorm.DB) *CartonSpecRepo {
	return &CartonSpecRepo{db: db}
}

func (r *CartonSpecRepo) Create(ctx context.Context, spec *model.CartonSpecification) error {
	err := r.db.WithContext(ctx).Create(spec).Error
	if isUniqueConflict(err) {
		return ErrCartonSpecConflict
	}
	return err
}

func (r *CartonSpecRepo) GetByID(ctx context.Context, id int64) (*model.CartonSpecification, error) {
	var spec model.CartonSpecification
	if err := r.db.WithContext(ctx).First(&spec, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrCartonSpecNotFound
		}
		return nil, err
	}
	return &spec, nil
}

func (r *CartonSpecRepo) List(ctx context.Context) ([]model.CartonSpecification, error) {
	var specs []model.CartonSpecification
	err := r.db.WithContext(ctx).Order("line_code ASC, product_code ASC, effective_from ASC").Find(&specs).Error
	return specs, err
}

func (r *CartonSpecRepo) Update(ctx context.Context, spec *model.CartonSpecification) error {
	if spec.ID == 0 {
		return ErrCartonSpecNotFound
	}
	result := r.db.WithContext(ctx).Save(spec)
	if result.Error != nil {
		if isUniqueConflict(result.Error) {
			return ErrCartonSpecConflict
		}
		return result.Error
	}
	return nil
}

func (r *CartonSpecRepo) Delete(ctx context.Context, id int64) error {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.DailyProductionPlan{}).
		Where("units_per_carton_snapshot IS NOT NULL").
		Count(&count).Error
	if err != nil {
		return err
	}

	var spec model.CartonSpecification
	if err := r.db.WithContext(ctx).First(&spec, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrCartonSpecNotFound
		}
		return err
	}

	result := r.db.WithContext(ctx).Delete(&model.CartonSpecification{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrCartonSpecNotFound
	}
	return nil
}

func (r *CartonSpecRepo) FindEffective(ctx context.Context, lineCode, productCode, date string) (*model.CartonSpecification, error) {
	var spec model.CartonSpecification
	err := r.db.WithContext(ctx).
		Where("line_code = ? AND product_code = ?", lineCode, productCode).
		Where("effective_from <= ?", date).
		Where("effective_to IS NULL OR effective_to >= ?", date).
		Order("effective_from DESC").
		First(&spec).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrCartonSpecNotFound
		}
		return nil, err
	}
	return &spec, nil
}