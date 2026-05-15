-- =============================================
-- 加工厂综合管理平台 完整建表脚本
-- DB: MySQL 5.7+ / 8.0
-- 包含：用户/物料/BOM/工序/生产/库存/采购/销售/模具/财务
-- =============================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================
-- 用户 / 角色 / 权限 模块建表脚本
-- 权限类型：菜单 + 按钮，支持树形层级
-- =============================================

-- 用户表
CREATE TABLE `user` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `username` VARCHAR(50) NOT NULL COMMENT '登录用户名',
  `password` VARCHAR(255) NOT NULL COMMENT '加密密码',
  `real_name` VARCHAR(50) DEFAULT NULL COMMENT '真实姓名',
  `phone` VARCHAR(30) DEFAULT NULL COMMENT '联系电话',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=启用, 0=停用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 角色表
CREATE TABLE `role` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '角色ID',
  `name` VARCHAR(50) NOT NULL COMMENT '角色名称，如：超级管理员、仓管员',
  `code` VARCHAR(50) NOT NULL COMMENT '角色编码，唯一标识，如：super_admin, warehouse',
  `description` VARCHAR(200) DEFAULT NULL COMMENT '角色描述',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=启用, 0=停用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色表';

-- 权限表（菜单 + 按钮，树形结构）
CREATE TABLE `permission` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '权限ID',
  `name` VARCHAR(50) NOT NULL COMMENT '权限名称，如：生产管理、新增订单',
  `code` VARCHAR(100) NOT NULL COMMENT '权限标识码，如：production:order:add',
  `type` VARCHAR(20) NOT NULL DEFAULT 'menu' COMMENT '权限类型：menu=菜单, button=按钮',
  `parent_id` INT DEFAULT NULL COMMENT '父权限ID，指向permission.id，NULL表示顶级菜单',
  `path` VARCHAR(200) DEFAULT NULL COMMENT '前端路由路径，菜单类型使用',
  `icon` VARCHAR(50) DEFAULT NULL COMMENT '菜单图标',
  `sort` INT DEFAULT 0 COMMENT '排序号，同级菜单按此升序排列',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=启用, 0=禁用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_perm_code` (`code`),
  KEY `idx_parent` (`parent_id`),
  KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='权限表（菜单+按钮，支持父子层级）';

-- 用户角色关联表
CREATE TABLE `user_role` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `user_id` INT NOT NULL COMMENT '用户ID，关联user.id',
  `role_id` INT NOT NULL COMMENT '角色ID，关联role.id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_role` (`user_id`, `role_id`),
  KEY `idx_role` (`role_id`),
  CONSTRAINT `fk_ur_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ur_role` FOREIGN KEY (`role_id`) REFERENCES `role` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户角色关联表';

-- 角色权限关联表
CREATE TABLE `role_permission` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `role_id` INT NOT NULL COMMENT '角色ID，关联role.id',
  `permission_id` INT NOT NULL COMMENT '权限ID，关联permission.id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_perm` (`role_id`, `permission_id`),
  KEY `idx_perm` (`permission_id`),
  CONSTRAINT `fk_rp_role` FOREIGN KEY (`role_id`) REFERENCES `role` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rp_perm` FOREIGN KEY (`permission_id`) REFERENCES `permission` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限关联表';

-- ==================== 2. 基础档案 ====================

CREATE TABLE `material` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '物料ID，主键自增',
  `code` VARCHAR(50) NOT NULL COMMENT '物料编码，唯一标识',
  `name` VARCHAR(100) NOT NULL COMMENT '物料名称',
  `category` VARCHAR(20) NOT NULL COMMENT '物料类别：raw=原材料, semi=半成品, finished=成品',
  `unit` VARCHAR(20) NOT NULL COMMENT '计量单位，如：个、kg、米、套',
  `specification` VARCHAR(200) DEFAULT NULL COMMENT '规格型号描述',
  `min_stock` DECIMAL(10,2) DEFAULT 0.00 COMMENT '安全库存下限，低于此数量预警',
  `max_stock` DECIMAL(10,2) DEFAULT 0.00 COMMENT '库存上限',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=正常, 0=停用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料表（原材料/半成品/成品）';

-- ==================== 3. 生产模块 ====================

CREATE TABLE `bom` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT 'BOM明细ID，主键自增',
  `parent_material_id` INT NOT NULL COMMENT '父物料ID（成品或半成品），关联material.id',
  `child_material_id` INT NOT NULL COMMENT '子物料ID（原材料或半成品），关联material.id',
  `quantity` DECIMAL(10,4) NOT NULL COMMENT '单位用量，生产1单位父物料所需的子物料数量',
  `scrap_rate` DECIMAL(5,4) DEFAULT 0.0000 COMMENT '损耗率，如0.02表示2%%损耗',
  `remark` VARCHAR(200) DEFAULT NULL COMMENT '备注',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_parent` (`parent_material_id`),
  KEY `idx_child` (`child_material_id`),
  CONSTRAINT `fk_bom_parent` FOREIGN KEY (`parent_material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_bom_child` FOREIGN KEY (`child_material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料清单表（BOM，定义成品/半成品的物料构成）';

CREATE TABLE `process` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '工序ID，主键自增',
  `code` VARCHAR(50) NOT NULL COMMENT '工序编码',
  `name` VARCHAR(100) NOT NULL COMMENT '工序名称，如：冲压、焊接、喷涂、组装',
  `description` VARCHAR(200) DEFAULT NULL COMMENT '工序描述',
  `standard_hours` DECIMAL(10,4) DEFAULT NULL COMMENT '标准工时（小时），用于排产计算',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工序模板表';

CREATE TABLE `material_process` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '物料工序流ID，主键自增',
  `material_id` INT NOT NULL COMMENT '物料ID（成品/半成品），关联material.id',
  `process_id` INT NOT NULL COMMENT '工序ID，关联process.id',
  `seq` INT NOT NULL COMMENT '工序顺序号，从1开始递增',
  `previous_process_id` INT DEFAULT NULL COMMENT '前序工序ID（material_process.id），NULL表示第一道工序',
  `mold_id` INT DEFAULT NULL COMMENT '本工序所需模具ID，关联mold.id，可为空',
  `setup_time` DECIMAL(10,4) DEFAULT NULL COMMENT '准备工时（小时），如换模调试时间',
  `run_time_per_unit` DECIMAL(10,4) DEFAULT NULL COMMENT '单件加工工时（小时/件）',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mat_seq` (`material_id`, `seq`),
  KEY `idx_process` (`process_id`),
  CONSTRAINT `fk_mp_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mp_process` FOREIGN KEY (`process_id`) REFERENCES `process` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料工序流表（定义某物料的生产工序顺序、所需模具及工时）';

CREATE TABLE `production_order` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '生产订单ID，主键自增',
  `order_no` VARCHAR(50) NOT NULL COMMENT '生产订单号，唯一编号',
  `material_id` INT NOT NULL COMMENT '要生产的物料ID（成品/半成品），关联material.id',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '计划生产数量',
  `finished_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '已完成合格数量（汇总报工数据）',
  `start_date` DATE DEFAULT NULL COMMENT '计划开工日期',
  `end_date` DATE DEFAULT NULL COMMENT '计划完工日期',
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT '订单状态：draft=草稿, released=已下达, in_progress=生产中, completed=已完成, closed=已关闭',
  `remark` TEXT COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '创建人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_material` (`material_id`),
  KEY `idx_status` (`status`),
  CONSTRAINT `fk_po_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产订单主表';

CREATE TABLE `production_report` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '报工ID，主键自增',
  `production_order_id` INT NOT NULL COMMENT '生产订单ID，关联production_order.id',
  `material_process_id` INT NOT NULL COMMENT '物料工序流ID，关联material_process.id，标识当前报工对应哪道工序',
  `reported_quantity` DECIMAL(10,2) NOT NULL COMMENT '本次报工合格数量',
  `defect_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '本次报工不良品数量',
  `start_time` DATETIME DEFAULT NULL COMMENT '本道工序开始时间',
  `end_time` DATETIME DEFAULT NULL COMMENT '本道工序结束时间',
  `mold_id` INT DEFAULT NULL COMMENT '实际使用的模具ID，关联mold.id',
  `operator_id` INT DEFAULT NULL COMMENT '操作工用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_order` (`production_order_id`),
  KEY `idx_mp` (`material_process_id`),
  CONSTRAINT `fk_pr_order` FOREIGN KEY (`production_order_id`) REFERENCES `production_order` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pr_mp` FOREIGN KEY (`material_process_id`) REFERENCES `material_process` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产报工记录表（按工序报工，记录合格/不良数量、工时及模具使用情况）';

CREATE TABLE `quality_check` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '质检记录ID，主键自增',
  `production_report_id` INT DEFAULT NULL COMMENT '关联的报工单ID，关联production_report.id，可为空',
  `check_quantity` DECIMAL(10,2) NOT NULL COMMENT '本次检验数量',
  `pass_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '合格数量',
  `result` VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '检验结果：pending=待检, pass=合格, fail=不合格',
  `inspector_id` INT DEFAULT NULL COMMENT '检验员用户ID，关联user.id',
  `check_date` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '检验时间',
  `remark` VARCHAR(200) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `idx_report` (`production_report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='质检记录表（可关联报工单进行工序检验）';

-- ==================== 4. 库存模块 ====================

CREATE TABLE `inventory_batch` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '批次ID，主键自增',
  `material_id` INT NOT NULL COMMENT '物料ID，关联material.id',
  `batch_no` VARCHAR(50) NOT NULL COMMENT '批次号，唯一标识（可含生产日期/采购单号等信息）',
  `quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '当前库存数量',
  `unit_cost` DECIMAL(10,4) NOT NULL DEFAULT 0.0000 COMMENT '移动加权平均单位成本',
  `total_cost` DECIMAL(12,4) GENERATED ALWAYS AS (`quantity` * `unit_cost`) STORED COMMENT '库存总金额（计算列=数量×单位成本）',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_batch` (`batch_no`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_batch_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存批次表（移动加权平均成本，出入库时均重算unit_cost）';

CREATE TABLE `inventory_transaction` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '库存流水ID，主键自增',
  `material_id` INT NOT NULL COMMENT '物料ID，关联material.id',
  `batch_id` INT NOT NULL COMMENT '批次ID，关联inventory_batch.id',
  `type` VARCHAR(20) NOT NULL COMMENT '出入库类型：purchase_in=采购入库, production_out=生产领料出库, production_in=生产完工入库, sales_out=销售出库, adjustment_in=盘盈入库, adjustment_out=盘亏出库',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '交易数量（正数为入库，负数为出库）',
  `unit_cost` DECIMAL(10,4) NOT NULL COMMENT '本次交易时的单位成本（快照）',
  `total_cost` DECIMAL(12,4) GENERATED ALWAYS AS (`quantity` * `unit_cost`) STORED COMMENT '本次交易总成本（计算列）',
  `reference_type` VARCHAR(30) DEFAULT NULL COMMENT '关联单据类型，如receipt/shipment/production_report',
  `reference_id` INT DEFAULT NULL COMMENT '关联单据ID，指向对应业务表的主键',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_material` (`material_id`),
  KEY `idx_batch` (`batch_id`),
  KEY `idx_reference` (`reference_type`, `reference_id`),
  CONSTRAINT `fk_it_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_it_batch` FOREIGN KEY (`batch_id`) REFERENCES `inventory_batch` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存流水表（所有出入库明细，记录每次交易的成本快照）';

-- ==================== 5. 采购模块 ====================

CREATE TABLE `supplier` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '供应商ID，主键自增',
  `code` VARCHAR(50) NOT NULL COMMENT '供应商编码，唯一标识',
  `name` VARCHAR(100) NOT NULL COMMENT '供应商名称',
  `contact_person` VARCHAR(50) DEFAULT NULL COMMENT '联系人姓名',
  `phone` VARCHAR(30) DEFAULT NULL COMMENT '联系电话',
  `address` VARCHAR(200) DEFAULT NULL COMMENT '地址',
  `initial_balance` DECIMAL(12,2) DEFAULT 0.00 COMMENT '期初应付余额',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=正常, 0=停用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_supplier_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='供应商档案表';

CREATE TABLE `purchase_order` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '采购订单ID，主键自增',
  `order_no` VARCHAR(50) NOT NULL COMMENT '采购订单号，唯一编号',
  `supplier_id` INT NOT NULL COMMENT '供应商ID，关联supplier.id',
  `order_date` DATE NOT NULL COMMENT '订单日期',
  `expected_date` DATE DEFAULT NULL COMMENT '预计到货日期',
  `total_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '订单总金额（汇总明细金额）',
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT '状态：draft=草稿, confirmed=已确认, partial_received=部分收货, received=已收货, closed=已关闭',
  `remark` TEXT COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '创建人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_po_no` (`order_no`),
  KEY `idx_supplier` (`supplier_id`),
  CONSTRAINT `fk_po_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `supplier` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单主表';

CREATE TABLE `purchase_order_item` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '采购订单明细ID，主键自增',
  `purchase_order_id` INT NOT NULL COMMENT '采购订单ID，关联purchase_order.id',
  `material_id` INT NOT NULL COMMENT '物料ID，关联material.id',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '采购数量',
  `unit_price` DECIMAL(10,2) NOT NULL COMMENT '采购单价',
  `received_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '已收货数量（汇总收货明细）',
  `status` VARCHAR(20) DEFAULT 'open' COMMENT '行状态：open=未收完, partial=部分收货, closed=已收完',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_po` (`purchase_order_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_poi_order` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_poi_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单明细表';

CREATE TABLE `receipt` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '收货单ID，主键自增',
  `receipt_no` VARCHAR(50) NOT NULL COMMENT '收货单号，唯一编号',
  `purchase_order_id` INT NOT NULL COMMENT '采购订单ID，关联purchase_order.id',
  `receipt_date` DATETIME NOT NULL COMMENT '收货日期',
  `total_quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '总收货数量（汇总明细）',
  `status` VARCHAR(20) NOT NULL DEFAULT 'confirmed' COMMENT '状态：confirmed=已确认入库（触发批次和流水）',
  `remark` TEXT COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '创建人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_receipt_no` (`receipt_no`),
  KEY `idx_po` (`purchase_order_id`),
  CONSTRAINT `fk_receipt_order` FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购收货单主表（确认后触发入库及应付）';

CREATE TABLE `receipt_item` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '收货明细ID，主键自增',
  `receipt_id` INT NOT NULL COMMENT '收货单ID，关联receipt.id',
  `purchase_order_item_id` INT NOT NULL COMMENT '采购订单明细ID，关联purchase_order_item.id',
  `material_id` INT NOT NULL COMMENT '物料ID，关联material.id',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '本次收货数量',
  `unit_cost` DECIMAL(10,2) NOT NULL COMMENT '入库成本单价（取自采购单价）',
  `inventory_batch_id` INT DEFAULT NULL COMMENT '收货后生成的库存批次ID，关联inventory_batch.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_receipt` (`receipt_id`),
  KEY `idx_poi` (`purchase_order_item_id`),
  KEY `idx_batch` (`inventory_batch_id`),
  CONSTRAINT `fk_ri_receipt` FOREIGN KEY (`receipt_id`) REFERENCES `receipt` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ri_poi` FOREIGN KEY (`purchase_order_item_id`) REFERENCES `purchase_order_item` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购收货明细表（收货即入库，创建批次并插入库存流水）';

-- ==================== 6. 销售模块 ====================

CREATE TABLE `customer` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '客户ID，主键自增',
  `code` VARCHAR(50) NOT NULL COMMENT '客户编码，唯一标识',
  `name` VARCHAR(100) NOT NULL COMMENT '客户名称',
  `contact_person` VARCHAR(50) DEFAULT NULL COMMENT '联系人姓名',
  `phone` VARCHAR(30) DEFAULT NULL COMMENT '联系电话',
  `address` VARCHAR(200) DEFAULT NULL COMMENT '地址',
  `initial_balance` DECIMAL(12,2) DEFAULT 0.00 COMMENT '期初应收余额',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '状态：1=正常, 0=停用',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户档案表';

CREATE TABLE `sales_order` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '销售订单ID，主键自增',
  `order_no` VARCHAR(50) NOT NULL COMMENT '销售订单号，唯一编号',
  `customer_id` INT NOT NULL COMMENT '客户ID，关联customer.id',
  `order_date` DATE NOT NULL COMMENT '订单日期',
  `delivery_date` DATE DEFAULT NULL COMMENT '要求交货日期',
  `total_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '订单总金额（汇总明细金额）',
  `status` VARCHAR(20) NOT NULL DEFAULT 'draft' COMMENT '状态：draft=草稿, confirmed=已确认, partial_shipped=部分发货, shipped=已发货, closed=已关闭',
  `remark` TEXT COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '创建人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_so_no` (`order_no`),
  KEY `idx_customer` (`customer_id`),
  CONSTRAINT `fk_so_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单主表';

CREATE TABLE `sales_order_item` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '销售订单明细ID，主键自增',
  `sales_order_id` INT NOT NULL COMMENT '销售订单ID，关联sales_order.id',
  `material_id` INT NOT NULL COMMENT '物料ID（成品），关联material.id',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '销售数量',
  `unit_price` DECIMAL(10,2) NOT NULL COMMENT '销售单价',
  `shipped_quantity` DECIMAL(10,2) DEFAULT 0.00 COMMENT '已发货数量（汇总发货明细）',
  `status` VARCHAR(20) DEFAULT 'open' COMMENT '行状态：open=未发完, partial=部分发货, closed=已发完',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_so` (`sales_order_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_soi_order` FOREIGN KEY (`sales_order_id`) REFERENCES `sales_order` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_soi_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单明细表';

CREATE TABLE `shipment` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '发货单ID，主键自增',
  `shipment_no` VARCHAR(50) NOT NULL COMMENT '发货单号，唯一编号',
  `sales_order_id` INT NOT NULL COMMENT '销售订单ID，关联sales_order.id',
  `shipment_date` DATETIME NOT NULL COMMENT '发货日期',
  `total_quantity` DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '总发货数量（汇总明细）',
  `status` VARCHAR(20) NOT NULL DEFAULT 'confirmed' COMMENT '状态：confirmed=已确认出库（扣减库存并生成应收）',
  `remark` TEXT COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '创建人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shipment_no` (`shipment_no`),
  KEY `idx_so` (`sales_order_id`),
  CONSTRAINT `fk_shipment_order` FOREIGN KEY (`sales_order_id`) REFERENCES `sales_order` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售发货单主表（确认后扣减库存并生成应收）';

CREATE TABLE `shipment_item` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '发货明细ID，主键自增',
  `shipment_id` INT NOT NULL COMMENT '发货单ID，关联shipment.id',
  `sales_order_item_id` INT NOT NULL COMMENT '销售订单明细ID，关联sales_order_item.id',
  `material_id` INT NOT NULL COMMENT '物料ID，关联material.id',
  `quantity` DECIMAL(10,2) NOT NULL COMMENT '本次发货数量',
  `unit_cost` DECIMAL(10,4) NOT NULL COMMENT '出库时的移动加权平均成本（成本快照）',
  `inventory_batch_id` INT DEFAULT NULL COMMENT '出库的库存批次ID，关联inventory_batch.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_shipment` (`shipment_id`),
  KEY `idx_soi` (`sales_order_item_id`),
  KEY `idx_batch` (`inventory_batch_id`),
  CONSTRAINT `fk_si_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_si_soi` FOREIGN KEY (`sales_order_item_id`) REFERENCES `sales_order_item` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售发货明细表（发货即出库，扣减批次、生成库存流水和应收）';

-- ==================== 7. 模具模块 ====================

CREATE TABLE `mold` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '模具ID，主键自增',
  `code` VARCHAR(50) NOT NULL COMMENT '模具编码，唯一标识',
  `name` VARCHAR(100) NOT NULL COMMENT '模具名称',
  `specification` VARCHAR(200) DEFAULT NULL COMMENT '规格型号',
  `location` VARCHAR(100) DEFAULT NULL COMMENT '存放位置',
  `purchase_date` DATE DEFAULT NULL COMMENT '购入日期',
  `purchase_cost` DECIMAL(10,2) DEFAULT NULL COMMENT '购置成本（元）',
  `max_usage` INT DEFAULT NULL COMMENT '寿命上限（次）',
  `current_usage` INT DEFAULT 0 COMMENT '当前使用次数（累计）',
  `status` VARCHAR(20) NOT NULL DEFAULT 'active' COMMENT '状态：active=使用中, repair=维修中, scrapped=已报废',
  `remark` TEXT COMMENT '备注',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mold_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具档案表（含使用寿命追踪，超出寿命预警）';

CREATE TABLE `mold_repair` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '维修记录ID，主键自增',
  `mold_id` INT NOT NULL COMMENT '模具ID，关联mold.id',
  `repair_date` DATE NOT NULL COMMENT '维修日期',
  `problem` VARCHAR(500) DEFAULT NULL COMMENT '故障描述',
  `solution` VARCHAR(500) DEFAULT NULL COMMENT '处理措施',
  `cost` DECIMAL(10,2) DEFAULT 0.00 COMMENT '维修费用（元）',
  `created_by` INT DEFAULT NULL COMMENT '登记人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_mold` (`mold_id`),
  CONSTRAINT `fk_mr_mold` FOREIGN KEY (`mold_id`) REFERENCES `mold` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具维修记录表';

CREATE TABLE `mold_material` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '关系ID，主键自增',
  `mold_id` INT NOT NULL COMMENT '模具ID，关联mold.id',
  `material_id` INT NOT NULL COMMENT '适用物料ID，关联material.id',
  `remark` VARCHAR(200) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `idx_mold` (`mold_id`),
  KEY `idx_material` (`material_id`),
  CONSTRAINT `fk_mm_mold` FOREIGN KEY (`mold_id`) REFERENCES `mold` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mm_material` FOREIGN KEY (`material_id`) REFERENCES `material` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='模具适用物料关系表';

-- ==================== 8. 财务模块 ====================

CREATE TABLE `receivable_payable` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '应收应付ID，主键自增',
  `type` VARCHAR(10) NOT NULL COMMENT '类型：AR=应收（客户欠款）, AP=应付（欠供应商款）',
  `source_type` VARCHAR(20) NOT NULL COMMENT '来源单据类型：sales_order=销售订单, purchase_order=采购订单',
  `source_id` INT NOT NULL COMMENT '来源单据ID，指向sales_order.id或purchase_order.id',
  `source_no` VARCHAR(50) NOT NULL COMMENT '来源单号（冗余，方便查询）',
  `counterparty_id` INT NOT NULL COMMENT '往来对象ID：type=AR时为customer.id, type=AP时为supplier.id',
  `amount` DECIMAL(12,2) NOT NULL COMMENT '原币金额',
  `paid_amount` DECIMAL(12,2) DEFAULT 0.00 COMMENT '已核销金额（累计收款/付款）',
  `due_date` DATE DEFAULT NULL COMMENT '到期日',
  `status` VARCHAR(20) DEFAULT 'open' COMMENT '状态：open=未结清, partial=部分核销, closed=已结清',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_type` (`type`),
  KEY `idx_source` (`source_type`, `source_id`),
  KEY `idx_counterparty` (`counterparty_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应收应付表（由采购入库/销售出库自动生成）';

CREATE TABLE `payment` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '收付款记录ID，主键自增',
  `payment_no` VARCHAR(50) NOT NULL COMMENT '收付款单号，唯一编号',
  `rp_id` INT NOT NULL COMMENT '应收应付ID，关联receivable_payable.id，标识核销哪笔账款',
  `counterparty_id` INT NOT NULL COMMENT '往来对象ID（客户或供应商）',
  `amount` DECIMAL(12,2) NOT NULL COMMENT '本次收付款金额',
  `payment_date` DATETIME NOT NULL COMMENT '收付款日期',
  `method` VARCHAR(30) DEFAULT NULL COMMENT '方式：cash=现金, bank_transfer=银行转账, alipay=支付宝, wechat=微信',
  `remark` VARCHAR(200) DEFAULT NULL COMMENT '备注',
  `created_by` INT DEFAULT NULL COMMENT '登记人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`),
  KEY `idx_rp` (`rp_id`),
  KEY `idx_counterparty` (`counterparty_id`),
  CONSTRAINT `fk_payment_rp` FOREIGN KEY (`rp_id`) REFERENCES `receivable_payable` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收款/付款记录表（核销应收应付）';

CREATE TABLE `expense` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '费用记录ID，主键自增',
  `category` VARCHAR(30) NOT NULL COMMENT '费用类别：water_electric=水电费, salary=工资, repair=维修费, office=办公费, rent=租金, other=其他',
  `amount` DECIMAL(10,2) NOT NULL COMMENT '费用金额（元）',
  `expense_date` DATE NOT NULL COMMENT '费用发生日期',
  `description` VARCHAR(300) DEFAULT NULL COMMENT '费用说明',
  `created_by` INT DEFAULT NULL COMMENT '登记人用户ID，关联user.id',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`),
  KEY `idx_date` (`expense_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='费用记录表（水电/工资/维修/办公/租金等）';

CREATE TABLE `cash_account` (
  `id` INT NOT NULL AUTO_INCREMENT COMMENT '资金账户ID，主键自增',
  `name` VARCHAR(50) NOT NULL COMMENT '账户名称，如：基本户、微信账户、现金',
  `balance` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '当前余额（元）',
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资金账户表（用于资产负债表现金项统计）';

SET FOREIGN_KEY_CHECKS = 1;