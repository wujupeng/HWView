package store

import (
	"context"
	"errors"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var (
	ErrSourceNotFound     = errors.New("data source not found")
	ErrSourceLineConflict = errors.New("data source line/base_path conflict")
)

type DataSourceRepo struct {
	db *gorm.DB
}

func NewDataSourceRepo(db *gorm.DB) *DataSourceRepo {
	return &DataSourceRepo{db: db}
}

func (r *DataSourceRepo) Create(ctx context.Context, src *model.DataSource) error {
	if src.LineID == 0 || src.CurrentIP == "" || src.BasePath == "" {
		return ErrRequiredFieldEmpty
	}
	if src.Status == "" {
		src.Status = model.SourceStatusOffline
	}
	err := r.db.WithContext(ctx).Create(src).Error
	if isUniqueConflict(err) {
		return ErrSourceLineConflict
	}
	return err
}

func (r *DataSourceRepo) GetByID(ctx context.Context, id int64) (*model.DataSource, error) {
	var src model.DataSource
	if err := r.db.WithContext(ctx).First(&src, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrSourceNotFound
		}
		return nil, err
	}
	return &src, nil
}

func (r *DataSourceRepo) ListByLine(ctx context.Context, lineID int64) ([]model.DataSource, error) {
	var sources []model.DataSource
	if err := r.db.WithContext(ctx).Where("line_id = ?", lineID).Find(&sources).Error; err != nil {
		return nil, err
	}
	return sources, nil
}

func (r *DataSourceRepo) List(ctx context.Context) ([]model.DataSource, error) {
	var sources []model.DataSource
	if err := r.db.WithContext(ctx).Order("id ASC").Find(&sources).Error; err != nil {
		return nil, err
	}
	return sources, nil
}

func (r *DataSourceRepo) UpdateCurrentIP(ctx context.Context, id int64, newIP string) error {
	result := r.db.WithContext(ctx).Model(&model.DataSource{}).Where("id = ?", id).Update("current_ip", newIP)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrSourceNotFound
	}
	return nil
}

func (r *DataSourceRepo) Update(ctx context.Context, src *model.DataSource) error {
	if src.ID == 0 {
		return ErrSourceNotFound
	}
	result := r.db.WithContext(ctx).Model(&model.DataSource{}).Where("id = ?", src.ID).Updates(src)
	if result.Error != nil {
		if isUniqueConflict(result.Error) {
			return ErrSourceLineConflict
		}
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrSourceNotFound
	}
	return nil
}

func (r *DataSourceRepo) Delete(ctx context.Context, id int64) error {
	result := r.db.WithContext(ctx).Delete(&model.DataSource{}, id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrSourceNotFound
	}
	return nil
}
