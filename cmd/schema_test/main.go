package main

import (
	"fmt"
	"log"
	"os"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func main() {
	os.Remove("data/test_schema.db")
	os.MkdirAll("data", 0755)

	db, err := gorm.Open(sqlite.Open("data/test_schema.db"), &gorm.Config{})
	if err != nil {
		log.Fatal(err)
	}

	sqlBytes, err := os.ReadFile("deploy/init_schema.sql")
	if err != nil {
		log.Fatal(err)
	}

	if err := db.Exec(string(sqlBytes)).Error; err != nil {
		log.Fatalf("SQL execution failed: %v", err)
	}

	tables := []string{
		"TBL_PRODUCTION_LINE", "TBL_DATA_SOURCE", "TBL_PRODUCTION_RECORD",
		"TBL_COLLECT_CURSOR", "TBL_DATA_SOURCE_HEALTH", "TBL_AGENT", "TBL_AUDIT_LOG",
	}
	for _, table := range tables {
		var count int
		query := fmt.Sprintf("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%s'", table)
		if err := db.Raw(query).Scan(&count).Error; err != nil {
			log.Fatalf("check table %s: %v", table, err)
		}
		if count != 1 {
			log.Fatalf("table %s not created", table)
		}
		fmt.Printf("OK: %s\n", table)
	}

	var lineCount int64
	if err := db.Raw("SELECT count(*) FROM TBL_PRODUCTION_LINE").Scan(&lineCount).Error; err != nil {
		log.Fatal(err)
	}
	fmt.Printf("TBL_PRODUCTION_LINE rows: %d (expect 1)\n", lineCount)
	if lineCount != 1 {
		log.Fatal("baseline insert failed")
	}

	fmt.Println("All schema validation passed!")
	os.Remove("data/test_schema.db")
}
