package collector

import (
	"context"

	"github.com/hwview/hwview/internal/store"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type schedulerRecordRepo struct {
	repo *store.ProductionRecordRepo
}

func newSchedulerRecordRepo(db *gorm.DB) *schedulerRecordRepo {
	return &schedulerRecordRepo{repo: store.NewProductionRecordRepo(db)}
}

func (r *schedulerRecordRepo) BatchUpsert(ctx context.Context, records []model.ProductionRecord) (int64, error) {
	return r.repo.BatchUpsert(ctx, records)
}

func (r *schedulerRecordRepo) GetCursor(ctx context.Context, lineID int64) (*model.CollectCursor, error) {
	return r.repo.GetCursor(ctx, lineID)
}

func (r *schedulerRecordRepo) UpsertCursor(ctx context.Context, cursor *model.CollectCursor) error {
	return r.repo.UpsertCursor(ctx, cursor)
}
