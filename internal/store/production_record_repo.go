package store

import (
	"context"
	"errors"

	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

var ErrRecordNotFound = errors.New("production record not found")

type ProductionRecordRepo struct {
	db *gorm.DB
}

func NewProductionRecordRepo(db *gorm.DB) *ProductionRecordRepo {
	return &ProductionRecordRepo{db: db}
}

func (r *ProductionRecordRepo) BatchUpsert(ctx context.Context, records []model.ProductionRecord) (int64, error) {
	if len(records) == 0 {
		return 0, nil
	}
	var inserted int64
	for _, rec := range records {
		result := r.db.WithContext(ctx).Where("line_id = ? AND source_id = ?", rec.LineID, rec.SourceID).
			FirstOrCreate(&rec)
		if result.Error != nil {
			return inserted, result.Error
		}
		if result.RowsAffected > 0 {
			inserted++
		}
	}
	return inserted, nil
}

func (r *ProductionRecordRepo) CountByLineAndDate(ctx context.Context, lineID int64, date string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.ProductionRecord{}).
		Where("line_id = ? AND production_date = ?", lineID, date).
		Count(&count).Error
	return count, err
}

func (r *ProductionRecordRepo) SumQuantityByLineAndDate(ctx context.Context, lineID int64, date string) (int64, error) {
	var sum int64
	err := r.db.WithContext(ctx).Model(&model.ProductionRecord{}).
		Where("line_id = ? AND production_date = ?", lineID, date).
		Select("COALESCE(SUM(quantity), 0)").Scan(&sum).Error
	return sum, err
}

func (r *ProductionRecordRepo) CountDistinctBatchByLineAndDate(ctx context.Context, lineID int64, date string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&model.ProductionRecord{}).
		Where("line_id = ? AND production_date = ?", lineID, date).
		Distinct("batch_no").Count(&count).Error
	return count, err
}

func (r *ProductionRecordRepo) ListByLineAndDate(ctx context.Context, lineID int64, date string) ([]model.ProductionRecord, error) {
	var records []model.ProductionRecord
	err := r.db.WithContext(ctx).
		Where("line_id = ? AND production_date = ?", lineID, date).
		Order("created_at ASC").Find(&records).Error
	return records, err
}

func (r *ProductionRecordRepo) GetCursor(ctx context.Context, lineID int64) (*model.CollectCursor, error) {
	var cursor model.CollectCursor
	err := r.db.WithContext(ctx).Where("line_id = ?", lineID).First(&cursor).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &cursor, err
}

func (r *ProductionRecordRepo) UpsertCursor(ctx context.Context, cursor *model.CollectCursor) error {
	var existing model.CollectCursor
	err := r.db.WithContext(ctx).Where("line_id = ?", cursor.LineID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return r.db.WithContext(ctx).Create(cursor).Error
	}
	if err != nil {
		return err
	}
	existing.SourceID = cursor.SourceID
	existing.LastCreatedAt = cursor.LastCreatedAt
	existing.LastSourceID = cursor.LastSourceID
	return r.db.WithContext(ctx).Save(&existing).Error
}
