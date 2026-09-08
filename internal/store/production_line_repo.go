package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var (
	ErrLineCodeConflict   = errors.New("line_code already exists")
	ErrRequiredFieldEmpty = errors.New("required field is empty")
	ErrLineNotFound       = errors.New("production line not found")
)

type ProductionLineRepo struct {
	db *gorm.DB
}

func NewProductionLineRepo(db *gorm.DB) *ProductionLineRepo {
	return &ProductionLineRepo{db: db}
}

func (r *ProductionLineRepo) Create(ctx context.Context, line *model.ProductionLine) error {
	if line.LineCode == "" || line.LineName == "" || line.Customer == "" || line.Product == "" || line.AdapterType == "" {
		return ErrRequiredFieldEmpty
	}
	if line.Status == "" {
		line.Status = model.LineStatusUnconfigured
	}
	err := r.db.WithContext(ctx).Create(line).Error
	if isUniqueConflict(err) {
		return ErrLineCodeConflict
	}
	return err
}

func (r *ProductionLineRepo) GetByID(ctx context.Context, id int64) (*model.ProductionLine, error) {
	var line model.ProductionLine
	if err := r.db.WithContext(ctx).First(&line, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrLineNotFound
		}
		return nil, err
	}
	return &line, nil
}

func (r *ProductionLineRepo) GetByCode(ctx context.Context, code string) (*model.ProductionLine, error) {
	var line model.ProductionLine
	if err := r.db.WithContext(ctx).Where("line_code = ?", code).First(&line).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrLineNotFound
		}
		return nil, err
	}
	return &line, nil
}

func (r *ProductionLineRepo) List(ctx context.Context) ([]model.ProductionLine, error) {
	var lines []model.ProductionLine
	if err := r.db.WithContext(ctx).Order("id ASC").Find(&lines).Error; err != nil {
		return nil, err
	}
	return lines, nil
}

func (r *ProductionLineRepo) Update(ctx context.Context, line *model.ProductionLine) error {
	if line.ID == 0 {
		return ErrLineNotFound
	}
	result := r.db.WithContext(ctx).Model(&model.ProductionLine{}).Where("id = ?", line.ID).Updates(line)
	if result.Error != nil {
		if isUniqueConflict(result.Error) {
			return ErrLineCodeConflict
		}
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrLineNotFound
	}
	return nil
}

func (r *ProductionLineRepo) Delete(ctx context.Context, id int64) error {
	result := r.db.WithContext(ctx).Delete(&model.ProductionLine{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrLineNotFound
	}
	return nil
}

func isUniqueConflict(err error) bool {
	if err == nil {
		return false
	}
	return fmt.Sprintf("%v", err) != "" && (contains(err, "UNIQUE") || contains(err, "duplicate"))
}

func contains(err error, substr string) bool {
	return len(err.Error()) > 0 && (indexOf(err.Error(), substr) >= 0)
}

func indexOf(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
