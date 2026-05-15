-- =============================================
-- 加工厂综合管理平台 完整建表脚本
-- DB: MySQL 5.7+ / 8.0
-- =============================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ==================== 基础档案 ====================

-- 用户表（简化角色，无审批流）
CREATE TABLE `user` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `real_name` VARCHAR(50) DEFAULT NULL,
  `role` VARCHAR(20) NOT NULL DEFAULT 'operator' COMMENT 'super_admin / admin / warehouse / operator',
  `phone` VARCHAR(30) DEFAULT NULL,
  `status` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 物料表（原材料、半成品、成品）
CREATE TABLE `material` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `category` VARCHAR(20) NOT NULL COMMENT 'raw / semi / finished',
  `unit` VARCHAR(20) NOT NULL COMMENT '计量单位',
  `specification` VARCHAR(200) DEFAULT NULL,
  `min_stock` DECIMAL(10,2) DEFAULT 0.00 COMMENT '安全库存',
  `max_stock` DECIMAL(10,2) DEFAULT 0.00,
  `status` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料表';

-- ==================== 生产模块 ====================

-- 物料清单（BOM）
CREATE TABLE `bom` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `parent_material_id` INT NOT NULL COMMENT '父物料（成品/半成品）',
  `child_material_id` INT NOT NULL COMMENT '子物料（原材料/半成品）',
  `quantity` DECIMAL(10,4) NOT NULL COMMENT '单位用量',
  `scrap_rate` DECIMAL(5,4) DEFAULT 0.0000 COMMENT '损耗率',
  `remark` VARCHAR(200) DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_parent` (`parent_material_id`),
  KEY `idx_child` (`child_material_id`),
  CONSTRAINT `fk_bom_parent` FOREIGN KEY (`parent_material_id`) REFERENCES `material` (`id`),
  CONSTRAINT `fk_bom_child` FOREIGN KEY (`child_material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='BOM表';

-- 工序模板
CREATE TABLE `process` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `description` VARCHAR(200) DEFAULT NULL,
  `standard_hours` DECIMAL(10,4) DEFAULT NULL COMMENT '标准工时',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工序表';

-- 物料工序流（定义某物料的生产工序顺序）
CREATE TABLE `material_process` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `material_id` INT NOT NULL,
  `process_id` INT NOT NULL,
  `seq` INT NOT NULL COMMENT '工序顺序号',
  `previous_process_id` INT DEFAULT NULL COMMENT '前序工序ID',
  `mold_id` INT DEFAULT NULL COMMENT '使用的模具',
  `setup_time` DECIMAL(10,4) DEFAULT NULL,
  `run_time_per_unit` DECIMAL(10,4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mat_seq` (`material_id`, `seq`),
  KEY `idx_process` (`process_id`),
  CONSTRAINT `fk_mp_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`),
  CONSTRAINT `fk_mp_process` FOREIGN KEY (`process_id`) REFERENCES `process` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料工序流';

-- 生产订单主表
CREATE TABLE `production_order` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(50) NOT NULL,
  `material_id` INT NOT NULL COMMENT '要生产的物料（成品/半成品）',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '计划生产数量',
  `finished_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '已完成数量',
  `start_date` DATE DEFAULT NULL,
  `end_date` DATE DEFAULT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT 'draft/released/in_progress/completed/closed',
  `remark` TEXT,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_material` (`material_id`),
  KEY `idx_status` (`status`),
  CONSTRAINT `fk_po_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产订单';

-- 生产报工记录（按工序）
CREATE TABLE `production_report` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `production_order_id` INT NOT NULL,
  `material_process_id` INT NOT NULL,
  `reported_quantity` DECIMAL(10,2) NOT NULL COMMENT '本次报工合格数量',
  `defect_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '不良数量',
  `start_time` DATETIME DEFAULT NULL,
  `end_time` DATETIME DEFAULT NULL,
  `mold_id` INT DEFAULT NULL COMMENT '实际使用模具',
  `operator_id` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order` (`production_order_id`),
  KEY `idx_mp` (`material_process_id`),
  CONSTRAINT `fk_pr_order` FOREIGN KEY (`production_order_id`) REFERENCES `production_order` (`id`),
  CONSTRAINT `fk_pr_mp` FOREIGN KEY (`material_process_id`) REFERENCES `material_process` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产报工';

-- 质检记录（可关联报工单）
CREATE TABLE `quality_check` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `production_report_id` INT DEFAULT NULL,
  `check_quantity` DECIMAL(10,2) NOT NULL,
  `pass_quantity` DECIMAL(10,2) DEFAULT 0.00,
  `result` VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT 'pass/fail/pending',
  `inspector_id` INT DEFAULT NULL,
  `check_date` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `remark` VARCHAR(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_report` (`production_report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='质检记录';

-- ==================== 库存模块 ====================

-- 库存批次（移动加权平均，出入库均更新成本）
CREATE TABLE `inventory_batch` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `material_id` INT NOT NULL,
  `batch_no` VARCHAR(50) NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '当前库存数量',
  `unit_cost` DECIMAL(10,4) NOT NULL DEFAULT 0.0000 COMMENT '移动加权平均单位成本',
  `total_cost` DECIMAL(12,4) GENERATED ALWAYS AS (`quantity` * `unit_cost`) STORED COMMENT '库存金额',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch` (`batch_no`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_batch_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存批次';

-- 库存流水（所有出入库明细）
CREATE TABLE `inventory_transaction` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `material_id` INT NOT NULL,
  `batch_id` INT NOT NULL,
  `type` VARCHAR(20) NOT NULL COMMENT 'purchase_in / production_out / production_in / sales_out / adjustment_in / adjustment_out',
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_cost` DECIMAL(10,4) NOT NULL COMMENT '本次交易时的单位成本',
  `total_cost` DECIMAL(12,4) GENERATED ALWAYS AS (`quantity` * `unit_cost`) STORED,
  `reference_type` VARCHAR(30) DEFAULT NULL COMMENT '关联单据类型',
  `reference_id` INT DEFAULT NULL COMMENT '关联单据ID',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_material` (`material_id`),
  KEY `idx_batch` (`batch_id`),
  KEY `idx_reference` (`reference_type`, `reference_id`),
  CONSTRAINT `fk_it_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`),
  CONSTRAINT `fk_it_batch` FOREIGN KEY (`batch_id`) REFERENCES `inventory_batch` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存流水';

-- ==================== 采购模块 ====================

CREATE TABLE `supplier` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `contact_person` VARCHAR(50) DEFAULT NULL,
  `phone` VARCHAR(30) DEFAULT NULL,
  `address` VARCHAR(200) DEFAULT NULL,
  `initial_balance` DECIMAL(12,2) DEFAULT 0.00 COMMENT '期初应付余额',
  `status` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_supplier_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='供应商';

CREATE TABLE `purchase_order` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(50) NOT NULL,
  `supplier_id` INT NOT NULL,
  `order_date` DATE NOT NULL,
  `expected_date` DATE DEFAULT NULL,
  `total_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT 'draft/confirmed/partial_received/received/closed',
  `remark` TEXT,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_po_no` (`order_no`),
  KEY `idx_supplier` (`supplier_id`),
  CONSTRAINT `fk_po_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `supplier` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单';

CREATE TABLE `purchase_order_item` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `purchase_order_id` INT NOT NULL,
  `material_id` INT NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_price` DECIMAL(10,2) NOT NULL,
  `received_quantity` DECIMAL(10,2) DEFAULT 0.00,
  `status` VARCHAR(20) DEFAULT 'open' COMMENT 'open/partial/closed',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_po` (`purchase_order_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_poi_order` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order` (`id`),
  CONSTRAINT `fk_poi_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单明细';

CREATE TABLE `receipt` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `receipt_no` VARCHAR(50) NOT NULL,
  `purchase_order_id` INT NOT NULL,
  `receipt_date` DATETIME NOT NULL,
  `total_quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `status` VARCHAR(20) NOT NULL DEFAULT 'confirmed' COMMENT 'confirmed 已确认入库',
  `remark` TEXT,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_receipt_no` (`receipt_no`),
  KEY `idx_po` (`purchase_order_id`),
  CONSTRAINT `fk_receipt_order` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收货单';

CREATE TABLE `receipt_item` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `receipt_id` INT NOT NULL,
  `purchase_order_item_id` INT NOT NULL,
  `material_id` INT NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '本次收货数量',
  `unit_cost` DECIMAL(10,2) NOT NULL COMMENT '入库成本单价',
  `inventory_batch_id` INT DEFAULT NULL COMMENT '收货后生成的批次ID',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_receipt` (`receipt_id`),
  KEY `idx_poi` (`purchase_order_item_id`),
  KEY `idx_batch` (`inventory_batch_id`),
  CONSTRAINT `fk_ri_receipt` FOREIGN KEY (`receipt_id`) REFERENCES `receipt` (`id`),
  CONSTRAINT `fk_ri_poi` FOREIGN KEY (`purchase_order_item_id`) REFERENCES `purchase_order_item` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收货明细';

-- ==================== 销售模块 ====================

CREATE TABLE `customer` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `contact_person` VARCHAR(50) DEFAULT NULL,
  `phone` VARCHAR(30) DEFAULT NULL,
  `address` VARCHAR(200) DEFAULT NULL,
  `initial_balance` DECIMAL(12,2) DEFAULT 0.00 COMMENT '期初应收余额',
  `status` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户';

CREATE TABLE `sales_order` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_no` VARCHAR(50) NOT NULL,
  `customer_id` INT NOT NULL,
  `order_date` DATE NOT NULL,
  `delivery_date` DATE DEFAULT NULL,
  `total_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT 'draft/confirmed/partial_shipped/shipped/closed',
  `remark` TEXT,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_so_no` (`order_no`),
  KEY `idx_customer` (`customer_id`),
  CONSTRAINT `fk_so_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单';

CREATE TABLE `sales_order_item` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `sales_order_id` INT NOT NULL,
  `material_id` INT NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_price` DECIMAL(10,2) NOT NULL,
  `shipped_quantity` DECIMAL(10,2) DEFAULT 0.00,
  `status` VARCHAR(20) DEFAULT 'open' COMMENT 'open/partial/closed',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_so` (`sales_order_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_soi_order` FOREIGN KEY (`sales_order_id`) REFERENCES `sales_order` (`id`),
  CONSTRAINT `fk_soi_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单明细';

CREATE TABLE `shipment` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `shipment_no` VARCHAR(50) NOT NULL,
  `sales_order_id` INT NOT NULL,
  `shipment_date` DATETIME NOT NULL,
  `total_quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `status` VARCHAR(20) NOT NULL DEFAULT 'confirmed' COMMENT 'confirmed 已出库',
  `remark` TEXT,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shipment_no` (`shipment_no`),
  KEY `idx_so` (`sales_order_id`),
  CONSTRAINT `fk_shipment_order` FOREIGN KEY (`sales_order_id`) REFERENCES `sales_order` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='发货单';

CREATE TABLE `shipment_item` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `shipment_id` INT NOT NULL,
  `sales_order_item_id` INT NOT NULL,
  `material_id` INT NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_cost` DECIMAL(10,4) NOT NULL COMMENT '出库时的移动加权成本',
  `inventory_batch_id` INT DEFAULT NULL COMMENT '出库批次',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_shipment` (`shipment_id`),
  KEY `idx_soi` (`sales_order_item_id`),
  KEY `idx_batch` (`inventory_batch_id`),
  CONSTRAINT `fk_si_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`id`),
  CONSTRAINT `fk_si_soi` FOREIGN KEY (`sales_order_item_id`) REFERENCES `sales_order_item` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='发货明细';

-- ==================== 模具模块 ====================

CREATE TABLE `mold` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `specification` VARCHAR(200) DEFAULT NULL,
  `location` VARCHAR(100) DEFAULT NULL,
  `purchase_date` DATE DEFAULT NULL,
  `purchase_cost` DECIMAL(10,2) DEFAULT NULL,
  `max_usage` INT DEFAULT NULL COMMENT '寿命上限(次)',
  `current_usage` INT DEFAULT 0 COMMENT '当前使用次数',
  `status` VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT 'active/repair/scrapped',
  `remark` TEXT,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mold_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具档案';

CREATE TABLE `mold_repair` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `mold_id` INT NOT NULL,
  `repair_date` DATE NOT NULL,
  `problem` VARCHAR(500) DEFAULT NULL,
  `solution` VARCHAR(500) DEFAULT NULL,
  `cost` DECIMAL(10,2) DEFAULT 0.00,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mold` (`mold_id`),
  CONSTRAINT `fk_mr_mold` FOREIGN KEY (`mold_id`) REFERENCES `mold` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具维修记录';

CREATE TABLE `mold_material` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `mold_id` INT NOT NULL,
  `material_id` INT NOT NULL,
  `remark` VARCHAR(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_mold` (`mold_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_mm_mold` FOREIGN KEY (`mold_id`) REFERENCES `mold` (`id`),
  CONSTRAINT `fk_mm_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具适用物料';

-- ==================== 财务模块 ====================

CREATE TABLE `receivable_payable` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(10) NOT NULL COMMENT 'AR=应收, AP=应付',
  `source_type` VARCHAR(20) NOT NULL COMMENT 'sales_order/purchase_order',
  `source_id` INT NOT NULL,
  `source_no` VARCHAR(50) NOT NULL COMMENT '来源单号',
  `counterparty_id` INT NOT NULL COMMENT '客户ID或供应商ID',
  `amount` DECIMAL(12,2) NOT NULL,
  `paid_amount` DECIMAL(12,2) DEFAULT 0.00,
  `due_date` DATE DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT 'open' COMMENT 'open/partial/closed',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_type` (`type`),
  KEY `idx_source` (`source_type`, `source_id`),
  KEY `idx_counterparty` (`counterparty_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应收应付';

CREATE TABLE `payment` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `payment_no` VARCHAR(50) NOT NULL,
  `rp_id` INT NOT NULL COMMENT '应收应付ID',
  `counterparty_id` INT NOT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `payment_date` DATETIME NOT NULL,
  `method` VARCHAR(30) DEFAULT NULL COMMENT 'cash/bank_transfer/...',
  `remark` VARCHAR(200) DEFAULT NULL,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`),
  KEY `idx_rp` (`rp_id`),
  KEY `idx_counterparty` (`counterparty_id`),
  CONSTRAINT `fk_payment_rp` FOREIGN KEY (`rp_id`) REFERENCES `receivable_payable` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收款/付款';

CREATE TABLE `expense` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(30) NOT NULL COMMENT '水电/工资/维修/办公/其他',
  `amount` DECIMAL(10,2) NOT NULL,
  `expense_date` DATE NOT NULL,
  `description` VARCHAR(300) DEFAULT NULL,
  `created_by` INT DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`),
  KEY `idx_date` (`expense_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='费用';

-- ==================== 资金账户（用于资产负债表现金项） ====================
CREATE TABLE `cash_account` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `balance` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资金账户';

SET FOREIGN_KEY_CHECKS = 1;