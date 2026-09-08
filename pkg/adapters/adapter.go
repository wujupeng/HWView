package adapters

import (
	"context"
	"fmt"
	"time"
)

type ProductionRecord struct {
	LineID         int64
	SourceID       string
	ProductCode    string
	Barcode        string
	BatchNo        string
	Quantity       int
	CreatedAt      time.Time
	ProductionDate string
}

type Cursor struct {
	LastCreatedAt time.Time
	LastSourceID  string
}

type DiscoverResult struct {
	Available     bool
	TotalEstimate int64
}

type FetchResult struct {
	RawData       []byte
	HasMore       bool
	NextPageToken string
	Records       []ProductionRecord
}

type ProductionAdapter interface {
	Name() string
	Discover(ctx context.Context, sourceURL string) (*DiscoverResult, error)
	Fetch(ctx context.Context, sourceURL string, start, end time.Time, cursor *Cursor) (*FetchResult, error)
	Parse(ctx context.Context, rawData []byte) ([]map[string]interface{}, error)
	Normalize(ctx context.Context, lineID int64, raw map[string]interface{}) (*ProductionRecord, error)
}

type Registry struct {
	adapters map[string]ProductionAdapter
}

func NewRegistry() *Registry {
	return &Registry{adapters: make(map[string]ProductionAdapter)}
}

func (r *Registry) Register(adapter ProductionAdapter) {
	r.adapters[adapter.Name()] = adapter
}

func (r *Registry) Get(name string) (ProductionAdapter, error) {
	a, ok := r.adapters[name]
	if !ok {
		return nil, fmt.Errorf("adapter %q not registered", name)
	}
	return a, nil
}

func (r *Registry) List() []string {
	names := make([]string, 0, len(r.adapters))
	for name := range r.adapters {
		names = append(names, name)
	}
	return names
}
