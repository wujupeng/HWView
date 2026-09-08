package config

import (
	"fmt"

	"github.com/spf13/viper"
)

type Config struct {
	Server    ServerConfig    `mapstructure:"server"`
	Database  DatabaseConfig  `mapstructure:"database"`
	Collector CollectorConfig `mapstructure:"collector"`
	Health    HealthConfig    `mapstructure:"health"`
	Auth      AuthConfig      `mapstructure:"auth"`
	Shadow    ShadowConfig    `mapstructure:"shadow"`
}

type ServerConfig struct {
	Host string `mapstructure:"host"`
	Port string `mapstructure:"port"`
	Mode string `mapstructure:"mode"`
}

type DatabaseConfig struct {
	Driver string `mapstructure:"driver"`
	DSN    string `mapstructure:"dsn"`
}

type CollectorConfig struct {
	CollectionInterval       string `mapstructure:"collection_interval"`
	AgentHeartbeatTimeout    string `mapstructure:"agent_heartbeat_timeout"`
	IPSwitchTimeout          string `mapstructure:"ip_switch_timeout"`
	DashboardPollingInterval string `mapstructure:"dashboard_polling_interval"`
}

type HealthConfig struct {
	ConsecutiveFailuresThreshold int `mapstructure:"consecutive_failures_threshold"`
	OfflineThreshold             int `mapstructure:"offline_threshold"`
}

type AuthConfig struct {
	Enabled  bool   `mapstructure:"enabled"`
	AdminKey string `mapstructure:"admin_key"`
}

type ShadowConfig struct {
	Enabled          bool   `mapstructure:"enabled"`
	CollectorShadow  bool   `mapstructure:"collector_shadow"`
	StatisticsShadow bool   `mapstructure:"statistics_shadow"`
	QuantityFrozen   bool   `mapstructure:"quantity_frozen"`
	QuantityLabel    string `mapstructure:"quantity_label"`
}

func Load(path string) (*Config, error) {
	viper.SetConfigFile(path)
	viper.AutomaticEnv()
	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}
	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}
	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (c *Config) validate() error {
	if c.Collector.CollectionInterval == "" {
		c.Collector.CollectionInterval = "5m"
	}
	if c.Collector.AgentHeartbeatTimeout == "" {
		c.Collector.AgentHeartbeatTimeout = "60s"
	}
	if c.Collector.IPSwitchTimeout == "" {
		c.Collector.IPSwitchTimeout = "30s"
	}
	if c.Collector.DashboardPollingInterval == "" {
		c.Collector.DashboardPollingInterval = "10s"
	}
	if c.Health.ConsecutiveFailuresThreshold == 0 {
		c.Health.ConsecutiveFailuresThreshold = 3
	}
	if c.Health.OfflineThreshold == 0 {
		c.Health.OfflineThreshold = 10
	}
	if c.Shadow.QuantityLabel == "" {
		c.Shadow.QuantityLabel = "pending business confirmation"
	}
	return nil
}
