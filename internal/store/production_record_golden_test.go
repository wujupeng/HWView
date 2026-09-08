package store

import (
	"context"
	"testing"
	"time"

	"github.com/hwview/hwview/pkg/model"
)

func TestProductionRecord_GoldenEvidence(t *testing.T) {
	db := setupTestDB(t)
	if err := db.AutoMigrate(&model.ProductionRecord{}, &model.ProductionLine{}); err != nil {
		t.Fatal(err)
	}
	lineRepo := NewProductionLineRepo(db)
	recordRepo := NewProductionRecordRepo(db)
	ctx := context.Background()

	line := model.ProductionLine{LineCode: "HW102-COPY", LineName: "华为102复制线", Customer: "华为", Product: "HW102", AdapterType: "Huawei102Adapter", Enabled: true}
	if err := lineRepo.Create(ctx, &line); err != nil {
		t.Fatal(err)
	}

	goldenDate := "2026-09-07"
	goldenBatch := "Q0926-078"
	goldenPieces := 5395
	goldenBoxes := 433

	records := make([]model.ProductionRecord, goldenBoxes)
	baseTime := time.Date(2026, 9, 7, 9, 0, 0, 0, time.Local)
	perBox := goldenPieces / goldenBoxes
	remainder := goldenPieces % goldenBoxes
	for i := 0; i < goldenBoxes; i++ {
		qty := perBox
		if i < remainder {
			qty++
		}
		records[i] = model.ProductionRecord{
			LineID:         line.ID,
			SourceID:       "BOX-" + padNum(i+1),
			ProductCode:    "HW102",
			Barcode:        "BAR-" + padNum(i+1),
			BatchNo:        goldenBatch,
			Quantity:       qty,
			CreatedAt:      baseTime.Add(time.Duration(i) * time.Minute),
			ProductionDate: goldenDate,
		}
	}

	inserted, err := recordRepo.BatchUpsert(ctx, records)
	if err != nil {
		t.Fatal(err)
	}
	if inserted != int64(goldenBoxes) {
		t.Fatalf("expected %d inserted, got %d", goldenBoxes, inserted)
	}

	inserted2, err := recordRepo.BatchUpsert(ctx, records)
	if err != nil {
		t.Fatal(err)
	}
	if inserted2 != 0 {
		t.Fatalf("repeated upsert should insert 0, got %d (UNIQUE constraint violation)", inserted2)
	}

	boxCount, err := recordRepo.CountByLineAndDate(ctx, line.ID, goldenDate)
	if err != nil {
		t.Fatal(err)
	}
	pieceCount, err := recordRepo.SumQuantityByLineAndDate(ctx, line.ID, goldenDate)
	if err != nil {
		t.Fatal(err)
	}
	batchCount, err := recordRepo.CountDistinctBatchByLineAndDate(ctx, line.ID, goldenDate)
	if err != nil {
		t.Fatal(err)
	}

	t.Logf("=== Golden Evidence Verification ===")
	t.Logf("Line:      HW102-COPY")
	t.Logf("Date:      %s", goldenDate)
	t.Logf("Boxes:     %d (expected %d) -> COUNT(DISTINCT source_id)", boxCount, goldenBoxes)
	t.Logf("Pieces:    %d (expected %d) -> SUM(quantity)", pieceCount, goldenPieces)
	t.Logf("Batches:   %d (expected 1) -> DISTINCT batch_no", batchCount)
	t.Logf("Batch No:  %s", goldenBatch)

	if boxCount != int64(goldenBoxes) {
		t.Errorf("box_count mismatch: got %d, want %d", boxCount, goldenBoxes)
	}
	if pieceCount != int64(goldenPieces) {
		t.Errorf("piece_count mismatch: got %d, want %d", pieceCount, goldenPieces)
	}
	if batchCount != 1 {
		t.Errorf("batch_count mismatch: got %d, want 1", batchCount)
	}
}

func padNum(n int) string {
	if n < 10 {
		return "00" + itoa(n)
	}
	if n < 100 {
		return "0" + itoa(n)
	}
	return itoa(n)
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	pos := len(buf)
	for n > 0 {
		pos--
		buf[pos] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[pos:])
}
