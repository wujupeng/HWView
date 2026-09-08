package collector

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/hwview/hwview/pkg/adapters"
	"github.com/hwview/hwview/pkg/model"
	"gorm.io/gorm"
)

type SourceResolver struct {
	db         *gorm.DB
	adapterReg *adapters.Registry
}

func NewSourceResolver(db *gorm.DB, reg *adapters.Registry) *SourceResolver {
	return &SourceResolver{db: db, adapterReg: reg}
}

type ResolvedSource struct {
	Line    model.ProductionLine
	Source  model.DataSource
	Adapter adapters.ProductionAdapter
}

func (r *SourceResolver) ResolveAll(ctx context.Context) ([]ResolvedSource, error) {
	var lines []model.ProductionLine
	if err := r.db.WithContext(ctx).Where("enabled = ?", true).Find(&lines).Error; err != nil {
		return nil, err
	}
	var result []ResolvedSource
	for _, line := range lines {
		var sources []model.DataSource
		if err := r.db.WithContext(ctx).Where("line_id = ? AND enabled = ?", line.ID, true).Find(&sources).Error; err != nil {
			slog.Error("resolve sources failed", "line", line.LineCode, "err", err)
			continue
		}
		adapter, err := r.adapterReg.Get(line.AdapterType)
		if err != nil {
			slog.Error("adapter not found", "line", line.LineCode, "adapter", line.AdapterType, "err", err)
			continue
		}
		for _, src := range sources {
			result = append(result, ResolvedSource{Line: line, Source: src, Adapter: adapter})
		}
	}
	return result, nil
}

func (r *SourceResolver) BuildSourceURL(src model.DataSource) string {
	return fmt.Sprintf("http://%s:%d%s", src.CurrentIP, src.Port, src.BasePath)
}

type IncrementalCollector struct {
	db         *gorm.DB
	resolver   *SourceResolver
	recordRepo recordRepoIface
}

type recordRepoIface interface {
	BatchUpsert(ctx context.Context, records []model.ProductionRecord) (int64, error)
	GetCursor(ctx context.Context, lineID int64) (*model.CollectCursor, error)
	UpsertCursor(ctx context.Context, cursor *model.CollectCursor) error
}

func NewIncrementalCollector(db *gorm.DB, resolver *SourceResolver, recordRepo recordRepoIface) *IncrementalCollector {
	return &IncrementalCollector{db: db, resolver: resolver, recordRepo: recordRepo}
}

func (c *IncrementalCollector) CollectAll(ctx context.Context) error {
	sources, err := c.resolver.ResolveAll(ctx)
	if err != nil {
		return err
	}
	for _, src := range sources {
		if err := c.collectOne(ctx, src); err != nil {
			slog.Error("collect line failed", "line", src.Line.LineCode, "err", err)
			continue
		}
	}
	return nil
}

func (c *IncrementalCollector) collectOne(ctx context.Context, src ResolvedSource) error {
	sourceURL := c.resolver.BuildSourceURL(src.Source)

	discoverResult, err := src.Adapter.Discover(ctx, sourceURL)
	if err != nil || !discoverResult.Available {
		return errors.New("source unavailable")
	}

	cursor, err := c.recordRepo.GetCursor(ctx, src.Line.ID)
	if err != nil {
		return err
	}

	var adapterCursor *adapters.Cursor
	if cursor != nil {
		adapterCursor = &adapters.Cursor{
			LastCreatedAt: cursor.LastCreatedAt,
			LastSourceID:  cursor.LastSourceID,
		}
	}

	end := time.Now()
	start := end.AddDate(0, 0, -1)
	fetchResult, err := src.Adapter.Fetch(ctx, sourceURL, start, end, adapterCursor)
	if err != nil {
		return err
	}

	for i := range fetchResult.Records {
		fetchResult.Records[i].LineID = src.Line.ID
		if fetchResult.Records[i].ProductCode == "" {
			fetchResult.Records[i].ProductCode = src.Line.Product
		}
	}

	records := make([]model.ProductionRecord, len(fetchResult.Records))
	for i, r := range fetchResult.Records {
		records[i] = model.ProductionRecord{
			LineID:         r.LineID,
			SourceID:       r.SourceID,
			ProductCode:    r.ProductCode,
			Barcode:        r.Barcode,
			BatchNo:        r.BatchNo,
			Quantity:       r.Quantity,
			CreatedAt:      r.CreatedAt,
			ProductionDate: r.ProductionDate,
		}
	}

	inserted, err := c.recordRepo.BatchUpsert(ctx, records)
	if err != nil {
		return err
	}

	if len(fetchResult.Records) > 0 {
		last := fetchResult.Records[len(fetchResult.Records)-1]
		newCursor := &model.CollectCursor{
			LineID:        src.Line.ID,
			SourceID:      last.SourceID,
			LastCreatedAt: last.CreatedAt,
			LastSourceID:  last.SourceID,
		}
		if err := c.recordRepo.UpsertCursor(ctx, newCursor); err != nil {
			return err
		}
	}

	slog.Info("collect success", "line", src.Line.LineCode, "fetched", len(fetchResult.Records), "inserted", inserted)
	return nil
}
