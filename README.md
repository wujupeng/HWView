# HWView-EV1

> HWView — Production Data View & Collection Platform
> 多产线数据采集与可视化平台

## 项目定位

HWView 是一个多产线生产数据采集与可视化平台，支持华为102、BMW、舍弗勒、麦格纳等多产线统一采集、统一存储、统一统计与可视化展示。

核心原则：**Line 是业务身份，Agent 是设备身份，IP 是动态位置，Adapter 是数据源协议。**

## 技术栈

### 后端
- Go 1.21+ / Gin 框架
- GORM（SQLite/PostgreSQL）
- goquery（HTML 解析）
- Viper（配置管理）
- slog（结构化日志）

### 前端
- React 18 + TypeScript (Strict)
- Vite 构建工具
- React Query（数据获取）
- Recharts（图表）
- React Router（路由）

### 数据库
- 表名规范：TBL_ 前缀加下划线分隔大写格式

## 目录结构

```
HWView/
├── cmd/
│   ├── hwview-server/       # 平台服务端入口
│   └── hwview-collector/    # 采集器入口
├── internal/
│   ├── server/              # REST API + Registry + Statistics
│   ├── collector/           # Scheduler + Incremental + Health
│   ├── store/               # DB 访问层
│   ├── audit/               # 审计日志
│   └── auth/                # 认证中间件
├── pkg/
│   ├── adapters/            # Adapter interface + Registry
│   │   ├── builtin/         # 内置 Adapter 注册
│   │   ├── huawei102/       # 华为102 Adapter
│   │   ├── bmw/             # BMW Adapter
│   │   ├── schaeffler/      # 舍弗勒 Adapter
│   │   ├── magna/           # 麦格纳 Adapter
│   │   └── generic/         # 通用 Adapter
│   └── model/               # 领域对象
├── config/                  # 配置文件
├── deploy/                  # 部署脚本与 SQL
└── web/                     # 前端工程
```

## 构建命令

### 后端
```bash
go vet ./...
go build ./...
go test ./...
```

### 前端
```bash
cd web
npm install
npm run dev      # 开发模式
npm run build    # 生产构建
```

## 部署

- 部署服务器：192.168.2.110
- OS 用户：debian（需 sudo 提权）
- 服务管理：systemd
- 凭据通过环境变量注入，禁止明文存储

## EV1 核心能力

1. 多产线注册
2. 多数据源管理
3. Agent 动态发现终端 IP（EV2）
4. Source Adapter 插件化
5. 统一 ProductionRecord
6. 每日产量/箱数/批次统计
7. 数据源健康监控
8. IP 变化自动切换（EV2）
9. Web Dashboard
10. 后续可增加产线不改核心架构

## Golden Evidence

- 产线：HW102-COPY
- 日期：2026-09-07
- 箱数：433
- 只数：5395
- 批次：Q0926-078