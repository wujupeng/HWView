package bmw

import (
	"context"
	"net/http"
	"time"

	"github.com/hwview/hwview/pkg/adapters"
)

type Adapter struct {
	httpClient *http.Client
}

func NewAdapter() *Adapter {
	return &Adapter{httpClient: &http.Client{Timeout: 10 * time.Second}}
}

func (a *Adapter) Name() string { return "BMWAdapter" }

func (a *Adapter) Discover(ctx context.Context, sourceURL string) (*adapters.DiscoverResult, error) {
	return &adapters.DiscoverResult{Available: false}, nil
}

func (a *Adapter) Fetch(ctx context.Context, sourceURL string, start, end time.Time, cursor *adapters.Cursor) (*adapters.FetchResult, error) {
	return &adapters.FetchResult{}, nil
}

func (a *Adapter) Parse(ctx context.Context, rawData []byte) ([]map[string]interface{}, error) {
	return nil, nil
}

func (a *Adapter) Normalize(ctx context.Context, lineID int64, raw map[string]interface{}) (*adapters.ProductionRecord, error) {
	return &adapters.ProductionRecord{LineID: lineID}, nil
}
