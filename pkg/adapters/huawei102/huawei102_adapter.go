package huawei102

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/hwview/hwview/pkg/adapters"
)

type Adapter struct {
	httpClient *http.Client
}

func NewAdapter() *Adapter {
	return &Adapter{httpClient: &http.Client{Timeout: 10 * time.Second}}
}

func (a *Adapter) Name() string { return "Huawei102Adapter" }

func (a *Adapter) Discover(ctx context.Context, sourceURL string) (*adapters.DiscoverResult, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, sourceURL, nil)
	if err != nil {
		return &adapters.DiscoverResult{Available: false}, err
	}
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return &adapters.DiscoverResult{Available: false}, nil
	}
	defer resp.Body.Close()
	return &adapters.DiscoverResult{Available: resp.StatusCode == http.StatusOK}, nil
}

func (a *Adapter) Fetch(ctx context.Context, sourceURL string, start, end time.Time, cursor *adapters.Cursor) (*adapters.FetchResult, error) {
	var allRecords []adapters.ProductionRecord
	page := 1
	hasMore := true

	for hasMore {
		pageURL := fmt.Sprintf("%s?date=%s&page=%d", sourceURL, start.Format("2006-01-02"), page)
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, nil)
		if err != nil {
			return nil, err
		}
		resp, err := a.httpClient.Do(req)
		if err != nil {
			return nil, err
		}
		rawData := make([]byte, 0)
		buf := make([]byte, 4096)
		for {
			n, rerr := resp.Body.Read(buf)
			if n > 0 {
				rawData = append(rawData, buf[:n]...)
			}
			if rerr != nil {
				break
			}
		}
		resp.Body.Close()

		rawMaps, err := a.Parse(ctx, rawData)
		if err != nil {
			return nil, err
		}
		for _, raw := range rawMaps {
			rec, err := a.Normalize(ctx, 0, raw)
			if err != nil {
				continue
			}
			if cursor != nil {
				if rec.CreatedAt.Before(cursor.LastCreatedAt) ||
					(rec.CreatedAt.Equal(cursor.LastCreatedAt) && rec.SourceID <= cursor.LastSourceID) {
					continue
				}
			}
			allRecords = append(allRecords, *rec)
		}

		hasMore = len(rawMaps) > 0 && strings.Contains(string(rawData), "\u4e0b\u4e00\u9875") && page < 10
		page++
	}

	return &adapters.FetchResult{Records: allRecords, HasMore: false}, nil
}

func (a *Adapter) Parse(ctx context.Context, rawData []byte) ([]map[string]interface{}, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(rawData)))
	if err != nil {
		return nil, err
	}
	var results []map[string]interface{}
	doc.Find("tbody tr").Each(func(_ int, s *goquery.Selection) {
		cells := s.Find("td")
		if cells.Length() < 5 {
			return
		}
		barcode := strings.TrimSpace(cells.Eq(1).Text())
		if barcode == "" || strings.Contains(barcode, "条码") || strings.Contains(barcode, "Barcode") {
			return
		}
		sourceID := ""
		href, exists := cells.Eq(0).Find("a").Attr("href")
		if exists {
			idx := strings.LastIndex(href, "/")
			if idx >= 0 && idx < len(href)-1 {
				sourceID = href[idx+1:]
			}
		}
		row := map[string]interface{}{
			"source_id":  sourceID,
			"barcode":    barcode,
			"quantity":   strings.TrimSpace(cells.Eq(2).Text()),
			"batch_no":   strings.TrimSpace(cells.Eq(3).Text()),
			"created_at": strings.TrimSpace(cells.Eq(4).Text()),
		}
		results = append(results, row)
	})
	return results, nil
}

func (a *Adapter) Normalize(ctx context.Context, lineID int64, raw map[string]interface{}) (*adapters.ProductionRecord, error) {
	sourceID, _ := raw["source_id"].(string)
	barcode, _ := raw["barcode"].(string)
	batchNo, _ := raw["batch_no"].(string)
	createdAtStr, _ := raw["created_at"].(string)
	quantityStr, _ := raw["quantity"].(string)

	quantity := 0
	for _, c := range quantityStr {
		if c >= '0' && c <= '9' {
			quantity = quantity*10 + int(c-'0')
		}
	}
	createdAt, _ := time.ParseInLocation("2006-01-02 15:04:05", createdAtStr, time.Local)

	return &adapters.ProductionRecord{
		LineID:         lineID,
		SourceID:       strings.TrimSpace(sourceID),
		ProductCode:    "HW102",
		Barcode:        strings.TrimSpace(barcode),
		BatchNo:        strings.TrimSpace(batchNo),
		Quantity:       quantity,
		CreatedAt:      createdAt,
		ProductionDate: createdAt.Format("2006-01-02"),
	}, nil
}

type LineAdapter struct {
	*Adapter
}

func NewLineAdapter() *LineAdapter {
	return &LineAdapter{Adapter: NewAdapter()}
}

func (a *LineAdapter) Name() string { return "Huawei102LineAdapter" }
