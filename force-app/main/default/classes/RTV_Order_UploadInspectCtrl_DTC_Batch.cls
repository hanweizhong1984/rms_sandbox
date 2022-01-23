public class RTV_Order_UploadInspectCtrl_DTC_Batch implements Database.Batchable<RMS_CSV_Iterator.OneLineInfo>,Database.Stateful{
  private Id theOrderId;
  /** 运行创建item */
  private Boolean createItemIfNotFound;

  /** 基础表：product */
  public Map<String, RMS_Product__c> products;

  /** 基础表：tradingTerm */
  public Map<String, RMS_TradingTerm__c> tradingTerms;

  /** 参数:csv内容 */
  private final Blob fileUploadBody;
  private final String fileCharset;
  private InspectInfo inspectInfo;

  /** 错误信息 */
  public Set<String> errorMessages = new Set<String>();

  /** csv的必须列 */
  private String[] Csv_Fields = new List<String>{ '退货授权号','Bar code','Material code','Style','Color','Size','申请数量','实收','备注','A','B','C','D','Reason code','差异'};

  /**item.recordtype */
  private RecordType dtcItemType = RMS_CommonUtil.getRecordTypes(
      'RTV_Order_Item__c'
    )
    .get('DTC');

  public Map<String,String> asiaUSMap = new Map<String,String>();

  public RTV_Order_UploadInspectCtrl_DTC_Batch(Blob fileUploadBody,String fileCharset,Boolean createItemIfNotFound) {
    this.fileUploadBody = fileUploadBody;
    this.fileCharset = fileCharset;
    this.createItemIfNotFound = createItemIfNotFound;
    this.inspectInfo = new InspectInfo();
  }

     /** 单个excute中的统计 */
     public class OneExecuteInfo {
	    Set<String> lfOrderCodes = new Set<String>();
	    Set<String> materialCodes = new Set<String>();
      /** 现存的order和item */
      Map<String, RTV_Order__c> existOrders = new Map<String,RTV_Order__c>();
      Map<String, RTV_Order_Item__c> existItems = new Map<String, RTV_Order_Item__c>();
      Map<String, RTV_Order_Inspection__c> existInspects = new Map<String,RTV_Order_Inspection__c>();
      //Map<String, List<Decimal>> actualMaps = new Map<String, List<Decimal>>();
      //Map<String, List<String>> remarkMaps = new Map<String, List<String>>();
      /** 待更新记录 */
      Map<String, RTV_Order__c> updateOrders = new Map<String,RTV_Order__c>();
      Map<String, RTV_Order_Item__c> updateItems = new Map<String, RTV_Order_Item__c>();
      Map<String, RTV_Order_Item__c> upsertItems = new Map<String, RTV_Order_Item__c>();
      Map<String, RTV_Order_Inspection__c> upsertInspects =new Map<String,RTV_Order_Inspection__c>();
     }

  /** 开始 */
  public Iterable<RMS_CSV_Iterator.OneLineInfo> start(Database.BatchableContext context) {
    // 返回csv迭代器
    RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(
      this.fileUploadBody,
      this.fileCharset
    );
    csvIter.skipTitleLine(Csv_Fields);
    this.sizeMap();

    return new RMS_CSV_Iterator.BatchIterable(csvIter);
  }
  /** 执行部分csv行 */
  public void execute(Database.BatchableContext context,List<RMS_CSV_Iterator.OneLineInfo> trs) {
    OneExecuteInfo oneExe = new OneExecuteInfo();
    this.products = new Map<String, RMS_Product__c>();
    this.tradingTerms = new Map<String, RMS_TradingTerm__c>();

    // 遍历csv行，统计lfOrderCode和materialcode
    for (RMS_CSV_Iterator.OneLineInfo tr : trs) {
      oneExe.lfOrderCodes.add(tr.get('退货授权号'));
      oneExe.materialCodes.add(tr.get('Material code'));
    }

    // 检索已存在的order和item和inspection
    this.queryItems(oneExe);

    // 遍历csv
    for (RMS_CSV_Iterator.OneLineInfo tr : trs) {
      // 通过'退货授权号'获取'OrderCode'和'BU2'
      String lfOrderCode = tr.get('退货授权号');
      String orderCode = lfOrderCode.substring(0, lfOrderCode.length() - 2);
      String bu2 = lfOrderCode.substring(
        lfOrderCode.length() - 2,
        lfOrderCode.length()
      );

      // 检查csv内容
      if (!checkCsvValues(tr)) {
        continue;
      }

      // 更新order
      RTV_Order__c order = changeOrder(oneExe,orderCode);

      // 更新item
      RTV_Order_Item__c item = changeItem(oneExe,order, bu2, tr);
      if (item == null) {
        continue;
      }
      
      // 更新inspect
      changeInspect(oneExe,item, tr);
    }

    for (String itemUniqueKey : this.inspectInfo.actualMaps.KeySet()) {
      RTV_Order_Item__c item = oneExe.existItems.get(itemUniqueKey);
      List<Decimal> actuals = this.inspectInfo.actualMaps.get(itemUniqueKey);
      List<String> remarks = this.inspectInfo.remarkMaps.get(itemUniqueKey);

      Decimal num = 0;
      String remark = '';
      if (actuals.size() > 0) {
        for (Decimal d : actuals) {
          num += d;
        }
      }
      if (remarks.size() > 0) {
        for (String r : remarks) {
          if (remark == r) {
            remark = r;
          } else {
            remark += r;
          }
        }
      }
      if (item != null) {
        oneExe.updateItems.put(
          itemUniqueKey,
          new RTV_Order_Item__c(
            Id = item.Id,
            Insp_Actual_QTY__c = num,
            Insp_WSL_Remark__c = remark
          )
        );
      }
    }
    // 创建或更新inspection
    if (!oneExe.upsertInspects.isEmpty()) {
      // 更新order
      if (!oneExe.updateOrders.isEmpty()) {
        update oneExe.updateOrders.values();
      }
      // 创建item
      if (!oneExe.upsertItems.isEmpty()) {
        upsert oneExe.upsertItems.values();
      }
      // 创建或更新inspection
      upsert oneExe.upsertInspects.values();

      if (!oneExe.updateItems.isEmpty()) {
        update oneExe.updateItems.values();
      }

      // 删除csv中没有的inspect记录
      //deleteOldItems();
    } else {
      this.errorMessages.add('system error.');
    }
  }

  /**
   * 统计order和item
   */
  private void queryItems(OneExecuteInfo oneExe) {
    Set<String> soldToCodes = new Set<String>();

    // 检索item，统计各 LF_Order_Auth_Code__c 对应的itemlist
    for (RTV_Order_Item__c item : [
      SELECT
        Id,
        Name,
        LF_Order_Auth_Code__c,
        UniqueKey__c,
        Product__c,
        Material_Code__c,
        BU_2__c,
        SKU_Size_US__c,
        Season_Code_CN__c,
        Bar_Code__c,
        POS_SKU__c,
        Application_QTY__c,
        Insp_Actual_QTY__c,
        RTV_Order__c,
        RTV_Order__r.Name,
        RTV_Order__r.Order_Auth_Code__c,
        RTV_Order__r.Status__c,
        RTV_Order__r.RTV_Defective__c,
        RTV_Order__r.Sold_To__r.Name,
        RTV_Order__r.Sold_To__r.TT_APP_ACC__c,
        RTV_Order__r.Sold_To__r.TT_FTW_EG__c,
        RTV_Order__r.Sold_To__r.TT_FW_Seasonal__c,
        (SELECT Id FROM RTV_Order_Inspections__r LIMIT 1)
      FROM RTV_Order_Item__c
      WHERE LF_Order_Auth_Code__c IN :oneExe.lfOrderCodes AND POS_SKU__c != NULL
    ]) {
      // 获取order
      String orderCode = item.RTV_Order__r.Order_Auth_Code__c;
      oneExe.existOrders.put(
        item.RTV_Order__r.Order_Auth_Code__c,
        item.RTV_Order__r
      );

      // 获取item的key = 授权码 + POS_SKU
      String itemUniqueKey = RMS_CommonUtil.item_getUniqueKeyDTC(
        orderCode,
        item.POS_SKU__c
      );

      // 获取现存的item
      oneExe.existItems.put(itemUniqueKey, item);

      // 获取现存的inspect
      if (!item.RTV_Order_Inspections__r.isEmpty()) {
        oneExe.existInspects.put(
          item.UniqueKey__c,
          item.RTV_Order_Inspections__r[0]
        );
      }

      soldToCodes.add(item.RTV_Order__r.Sold_To__r.Name);
    }

    // --------- 由于DTC的Inspect没有季节码，所以匹配不到商品 -----------------
    // 检索csv中提到的Product
    for (RMS_Product__c pdt : [
      SELECT
        Id,
        SKU__c,
        Material_Code__c,
        Season_Code_CN__c,
        MSRP__c,
        BUCN__c,
        BU__c
      FROM RMS_Product__c
      WHERE Material_Code__c IN :oneExe.materialCodes
    ]) {
      this.products.put(pdt.Material_Code__c, pdt);
    }
    // --------- 由于DTC的Inspect没有季节码，所以匹配不到商品 -----------------

    // 检索各个财年的TradingTerm
    for (RMS_TradingTerm__c tt : [
      SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name
      FROM RMS_TradingTerm__c
      WHERE Sold_To_Code__c IN :soldToCodes
    ]) {
      this.tradingTerms.put(tt.Name, tt);
    }
  }

  /** 修改 RTV_Order__c */
  private RTV_Order__c changeOrder(OneExecuteInfo oneExe,String orderCode) {
    // 获取数据库中的order
    RTV_Order__c order = oneExe.existOrders.get(orderCode);
    // 没有时报错
    if (order == null) {
      throw new RMS_CommonUtil.RMSException('未知的授权码: ' + orderCode);
    }
    // 参数指定了单个order时,不能上传其它order的内容
    if (this.theOrderId != null && this.theOrderId != order.Id) {
      throw new RMS_CommonUtil.RMSException(
        '请只上传此授权码的订单:' + orderCode
      );
    }
    // 检查order状态
    if (
      !(new List<String>{ 'Delivered', 'Inspected' }).contains(order.Status__c)
    ) {
      throw new RMS_CommonUtil.RMSException(
        '请不要上传其它状态的订单:' +
        order.Name +
        ', 状态=' +
        order.Status__c
      );
    }
    // 检查遍历过记录
    if (!oneExe.updateOrders.containsKey(orderCode)) {
      // 添加到待更新
      oneExe.updateOrders.put(
        orderCode,
        new RTV_Order__c(
          Id = order.Id,
          Inspect_By__c = UserInfo.getUserId(),
          Status__c = 'Inspected'
        )
      );
    }
    return order;
  }

  /** 修改 RTV_Order_Item__c */
  private RTV_Order_Item__c changeItem(OneExecuteInfo oneExe,RTV_Order__c order,String itemBu2,RMS_CSV_Iterator.OneLineInfo tr) {
    // ----------------------------
    // 获取Product
    // ※ POS_SKU__c = Product.SKU__c + Size
    // ----------------------------
    String posSku;
    String size;
    RMS_Product__c pdt = this.products.get(tr.get('Material code'));
    if (pdt != null) {
      size = RMS_CommonUtil.size_Us2Asia(tr.get('Size'), itemBu2); //美码转亚码
      //查看该size是否为特殊的size (AP中某些裤子material的尺码)
      if(asiaUSMap.containsKey(tr.get('Material code')+tr.get('Size'))){
        size= asiaUSMap.get(tr.get('Material code')+tr.get('Size'));
      }
      posSku = RMS_CommonUtil.item_getPosSku(pdt, size);
    }

    // 获取item.Key
    String itemUniqueKey = RMS_CommonUtil.item_getUniqueKeyDTC(
      order.Order_Auth_Code__c,
      posSku
    );

    if (this.inspectInfo.actualMaps.containsKey(itemUniqueKey)) {
      this.inspectInfo.actualMaps.get(itemUniqueKey).add(tr.getDecimal('实收', 0));
    } else {
      this.inspectInfo.actualMaps.put(itemUniqueKey,new List<Decimal>{ tr.getDecimal('实收', 0) });
    }

    if (this.inspectInfo.remarkMaps.containsKey(itemUniqueKey)) {
      this.inspectInfo.remarkMaps.get(itemUniqueKey).add(tr.get('备注'));
    } else {
      this.inspectInfo.remarkMaps.put(itemUniqueKey, new List<String>{ tr.get('备注') });
    }

    // ----------------------------
    // 新增item
    // ----------------------------
    RTV_Order_Item__c item = oneExe.existItems.get(itemUniqueKey);
    if (pdt == null || item == null) {
      // 不允许新增时，报错
      if (createItemIfNotFound == false) {
        throw new RMS_CommonUtil.RMSException(
          '(行' +
          tr.lineIndex +
          ') 该商品不在申请范围中:' +
          '  Order=' +
          order.Order_Auth_Code__c +
          ', POS SKU=' +
          posSku +
          '  (请确认CSV，或勾选"自动创建装箱单...")'
        );
      }

      // 获取遍历过记录
      item = oneExe.upsertItems.get(itemUniqueKey);
      if (item == null) {
        item = new RTV_Order_Item__c();

        // item.商品信息
        item.POS_SKU__c = posSku;
        item.Material_Code__c = tr.get('Material code');
        item.BU_2__c = itemBu2;
        item.Season_Code_CN__c = tr.get('季节码');
        item.SKU_Style__c = tr.get('Style');
        item.SKU_Color__c = tr.get('Color');
        item.Bar_Code__c = tr.get('Bar code');
        //item.Insp_Actual_QTY__c = tr.getDecimal('实收', 0);
        item.Insp_WSL_Remark__c = tr.get('备注');

        // item记录中的Size = inseption中(FW的)尺码除以10
        item.SKU_Size_US__c = RMS_CommonUtil.size_lfUs2Us(size, itemBu2);

        // item.商品对象信息
        if (pdt != null) {
          item.Product__c = pdt.Id;
        }

        // item.唯一键信息
        item.RTV_Order__r = new RTV_Order__c(
          Order_Auth_Code__c = order.Order_Auth_Code__c
        );
        item.UniqueKey__c = itemUniqueKey;
        item.Name = RMS_CommonUtil.item_getNameDTC(item);
        item.RecordTypeId = this.dtcItemType.Id;

        // 加到待添加的item里
        oneExe.upsertItems.put(item.UniqueKey__c, item);
      }
    } else {
      // ----------------------------
      // 更新item
      // ----------------------------
      // 检查遍历过记录
      if (!oneExe.upsertInspects.containsKey(itemUniqueKey)) {
        // 更新item信息
        item.UniqueKey__c = itemUniqueKey;
        item.Material_Code__c = tr.get('Material Code');
        item.SKU_Style__c = tr.get('Style');
        item.SKU_Color__c = tr.get('Color');
        item.Bar_Code__c = tr.get('Bar code');
        //item.Insp_Actual_QTY__c = tr.getDecimal('实收', 0);
        item.Insp_WSL_Remark__c = tr.get('备注');
        // item记录中的Size = inseption中(FW的)尺码除以10
        item.SKU_Size_US__c = RMS_CommonUtil.size_lfUs2Us(size, itemBu2);

        // 添加到待更新（只添加需要更新的字段）
        oneExe.upsertItems.put(
          item.UniqueKey__c,
          new RTV_Order_Item__c(
            Id = item.Id,
            UniqueKey__c = item.UniqueKey__c,
            SKU_Style__c = item.SKU_Style__c,
            SKU_Color__c = item.SKU_Color__c,
            Bar_Code__c = item.Bar_Code__c,
            //Insp_Actual_QTY__c=item.Insp_Actual_QTY__c,
            Insp_WSL_Remark__c = item.Insp_WSL_Remark__c
          )
        );
      }
    }
    return item;
  }

  /** 修改 RTV_Order_Inspection__c */
  private RTV_Order_Inspection__c changeInspect(OneExecuteInfo oneExe,RTV_Order_Item__c item,RMS_CSV_Iterator.OneLineInfo tr) {
    // 获取待更新记录
    RTV_Order_Inspection__c updInsp = oneExe.upsertInspects.get(item.UniqueKey__c);
    //用于统计Inspection中abcd数量
    RTV_Order_Inspection__c insp = this.inspectInfo.inspectMap.get(item.UniqueKey__c);

    if (updInsp == null && insp == null) {
      // 设置空白记录 (PS:每个order都请上传完整的inspection信息)
      updInsp = new RTV_Order_Inspection__c();
      updInsp.A__c = 0;
      updInsp.B1__c = 0;
      updInsp.B2__c = 0;
      updInsp.B2_1__c = 0;
      updInsp.B3__c = 0;
      updInsp.B4__c = 0;
      updInsp.B5__c = 0;
      updInsp.B6__c = 0;
      updInsp.B7__c = 0;
      updInsp.C1__c = 0;
      updInsp.C2_1__c = 0;
      updInsp.C2_2__c = 0;
      updInsp.C2_3__c = 0;
      updInsp.C2_4__c = 0;
      updInsp.C2_5__c = 0;
      updInsp.C2_6__c = 0;
      updInsp.C2_6_1__c = 0;
      updInsp.C2_7__c = 0;
      updInsp.D__c = 0;
      updInsp.Application_QTY_A__c = 0;
      updInsp.Application_QTY_B1__c = 0;
      updInsp.Application_QTY_B2__c = 0;
      updInsp.Application_QTY_B2_1__c = 0;
      updInsp.Application_QTY_B3__c = 0;
      updInsp.Application_QTY_B4__c = 0;
      updInsp.Application_QTY_B5__c = 0;
      updInsp.Application_QTY_B6__c = 0;
      updInsp.Application_QTY_B7__c = 0;
      updInsp.Application_QTY_C1__c = 0;
      updInsp.Application_QTY_C2_1__c = 0;
      updInsp.Application_QTY_C2_2__c = 0;
      updInsp.Application_QTY_C2_3__c = 0;
      updInsp.Application_QTY_C2_4__c = 0;
      updInsp.Application_QTY_C2_5__c = 0;
      updInsp.Application_QTY_C2_6__c = 0;
      updInsp.Application_QTY_C2_6_1__c = 0;
      updInsp.Application_QTY_C2_7__c = 0;
      updInsp.Application_QTY_D__c = 0;
      updInsp.Diff_QTY_A__c = 0;
      updInsp.Diff_QTY_B1__c = 0;
      updInsp.Diff_QTY_B2__c = 0;
      updInsp.Diff_QTY_B2_1__c = 0;
      updInsp.Diff_QTY_B3__c = 0;
      updInsp.Diff_QTY_B4__c = 0;
      updInsp.Diff_QTY_B5__c = 0;
      updInsp.Diff_QTY_B6__c = 0;
      updInsp.Diff_QTY_B7__c = 0;
      updInsp.Diff_QTY_C1__c = 0;
      updInsp.Diff_QTY_C2_1__c = 0;
      updInsp.Diff_QTY_C2_2__c = 0;
      updInsp.Diff_QTY_C2_3__c = 0;
      updInsp.Diff_QTY_C2_4__c = 0;
      updInsp.Diff_QTY_C2_5__c = 0;
      updInsp.Diff_QTY_C2_6__c = 0;
      updInsp.Diff_QTY_C2_6_1__c = 0;
      updInsp.Diff_QTY_C2_7__c = 0;
      updInsp.Diff_QTY_D__c = 0;

      updInsp.Delivery_QTY_A__c = 0;
      updInsp.Delivery_QTY_B1__c = 0;
      updInsp.Delivery_QTY_B2__c = 0;
      updInsp.Delivery_QTY_B2_1__c = 0;
      updInsp.Delivery_QTY_B3__c = 0;
      updInsp.Delivery_QTY_B4__c = 0;
      updInsp.Delivery_QTY_B5__c = 0;
      updInsp.Delivery_QTY_B6__c = 0;
      updInsp.Delivery_QTY_B7__c = 0;
      updInsp.Delivery_QTY_C1__c = 0;
      updInsp.Delivery_QTY_C2_1__c = 0;
      updInsp.Delivery_QTY_C2_2__c = 0;
      updInsp.Delivery_QTY_C2_3__c = 0;
      updInsp.Delivery_QTY_C2_4__c = 0;
      updInsp.Delivery_QTY_C2_5__c = 0;
      updInsp.Delivery_QTY_C2_6__c = 0;
      updInsp.Delivery_QTY_C2_6_1__c = 0;
      updInsp.Delivery_QTY_C2_7__c = 0;
      updInsp.Delivery_QTY_D__c = 0;

      // 设置数据库中该inspect的id，即更新该记录
      RTV_Order_Inspection__c extInsp = oneExe.existInspects.get(item.UniqueKey__c);
      if (extInsp != null) {
        updInsp.Id = extInsp.Id;
      }
      // 设置关联item
      updInsp.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c = item.UniqueKey__c);
      insp = updInsp;
      this.inspectInfo.inspectMap.put(item.UniqueKey__c,insp);
    }
    // 合计该inspect的Qty
    this.sumQtyOfOneInspect(this.inspectInfo.inspectMap.get(item.UniqueKey__c), tr);

    // 加到待upsert记录里
    oneExe.upsertInspects.put(item.UniqueKey__c, this.inspectInfo.inspectMap.get(item.UniqueKey__c));
    return this.inspectInfo.inspectMap.get(item.UniqueKey__c);
  }

  /** Inspection中各QTY字段赋值 */
  private void sumQtyOfOneInspect(RTV_Order_Inspection__c insp,RMS_CSV_Iterator.OneLineInfo tr) {
    String reasonCode = tr.get('Reason code');
    Decimal qtyA = tr.getDecimal('A', 0);
    Decimal qtyB = tr.getDecimal('B', 0);
    Decimal qtyC = tr.getDecimal('C', 0);
    Decimal qtyD = tr.getDecimal('D', 0);
    Decimal appQty = tr.getDecimal('申请数量', 0);
    Decimal diffQty = tr.getDecimal('差异', 0);
    Decimal deliveryQty = tr.getDecimal('实收', 0);

    if (reasonCode == 'A') {
      insp.A__c += qtyA;
      insp.Application_QTY_A__c += appQty;
      insp.Diff_QTY_A__c += diffQty;
      insp.Delivery_QTY_A__c += deliveryQty;
    } else if (reasonCode == 'B1') {
      insp.B1__c += qtyB;
      insp.Application_QTY_B1__c += appQty;
      insp.Diff_QTY_B1__c += diffQty;
      insp.Delivery_QTY_B1__c += deliveryQty;
    } else if (reasonCode == 'B2') {
      insp.B2__c += qtyB;
      insp.Application_QTY_B2__c += appQty;
      insp.Diff_QTY_B2__c += diffQty;
      insp.Delivery_QTY_B2__c += deliveryQty;
    } else if (reasonCode == 'B2-1') {
      insp.B2_1__c += qtyB;
      insp.Application_QTY_B2_1__c += appQty;
      insp.Diff_QTY_B2_1__c += diffQty;
      insp.Delivery_QTY_B2_1__c += deliveryQty;
    } else if (reasonCode == 'B3') {
      insp.B3__c += qtyB;
      insp.Application_QTY_B3__c += appQty;
      insp.Diff_QTY_B3__c += diffQty;
      insp.Delivery_QTY_B3__c += deliveryQty;
    } else if (reasonCode == 'B4') {
      insp.B4__c += qtyB;
      insp.Application_QTY_B4__c += appQty;
      insp.Diff_QTY_B4__c += diffQty;
      insp.Delivery_QTY_B4__c += deliveryQty;
    } else if (reasonCode == 'B5') {
      insp.B5__c += qtyB;
      insp.Application_QTY_B5__c += appQty;
      insp.Diff_QTY_B5__c += diffQty;
      insp.Delivery_QTY_B5__c += deliveryQty;
    } else if (reasonCode == 'B6') {
      insp.B6__c += qtyB;
      insp.Application_QTY_B6__c += appQty;
      insp.Diff_QTY_B6__c += diffQty;
      insp.Delivery_QTY_B6__c += deliveryQty;
    } else if (reasonCode == 'B7') {
      insp.B7__c += qtyB;
      insp.Application_QTY_B7__c += appQty;
      insp.Diff_QTY_B7__c += diffQty;
      insp.Delivery_QTY_B7__c += deliveryQty;
    } else if (reasonCode == 'C1') {
      insp.C1__c += qtyC;
      insp.Application_QTY_C1__c += appQty;
      insp.Diff_QTY_C1__c += diffQty;
      insp.Delivery_QTY_C1__c += deliveryQty;
    } else if (reasonCode == 'C2-1') {
      insp.C2_1__c += qtyC;
      insp.Application_QTY_C2_1__c += appQty;
      insp.Diff_QTY_C2_1__c += diffQty;
      insp.Delivery_QTY_C2_1__c += deliveryQty;
    } else if (reasonCode == 'C2-2') {
      insp.C2_2__c += qtyC;
      insp.Application_QTY_C2_2__c += appQty;
      insp.Diff_QTY_C2_2__c += diffQty;
      insp.Delivery_QTY_C2_2__c += deliveryQty;
    } else if (reasonCode == 'C2-3') {
      insp.C2_3__c += qtyC;
      insp.Application_QTY_C2_3__c += appQty;
      insp.Diff_QTY_C2_3__c += diffQty;
      insp.Delivery_QTY_C2_3__c += deliveryQty;
    } else if (reasonCode == 'C2-4') {
      insp.C2_4__c += qtyC;
      insp.Application_QTY_C2_4__c += appQty;
      insp.Diff_QTY_C2_4__c += diffQty;
      insp.Delivery_QTY_C2_4__c += deliveryQty;
    } else if (reasonCode == 'C2-5') {
      insp.C2_5__c += qtyC;
      insp.Application_QTY_C2_5__c += appQty;
      insp.Diff_QTY_C2_5__c += diffQty;
      insp.Delivery_QTY_C2_5__c += deliveryQty;
    } else if (reasonCode == 'C2-6') {
      insp.C2_6__c += qtyC;
      insp.Application_QTY_C2_6__c += appQty;
      insp.Diff_QTY_C2_6__c += diffQty;
      insp.Delivery_QTY_C2_6__c += deliveryQty;
    } else if (reasonCode == 'C2-6-1') {
      insp.C2_6_1__c += qtyC;
      insp.Application_QTY_C2_6_1__c += appQty;
      insp.Diff_QTY_C2_6_1__c += diffQty;
      insp.Delivery_QTY_C2_6_1__c += deliveryQty;
    } else if (reasonCode == 'C2-7') {
      insp.C2_7__c += qtyC;
      insp.Application_QTY_C2_7__c += appQty;
      insp.Diff_QTY_C2_7__c += diffQty;
      insp.Delivery_QTY_C2_7__c += deliveryQty;
    } else if (reasonCode == 'D') {
      insp.D__c += qtyD;
      insp.Application_QTY_D__c += appQty;
      insp.Diff_QTY_D__c += diffQty;
      insp.Delivery_QTY_D__c += deliveryQty;
    } else if (qtyA * qtyB * qtyC * qtyD != 0) {
      throw new RMS_CommonUtil.RMSException(
        '未知的 Reason code: ' + reasonCode
      );
    }
  }

  private void sizeMap(){
      //获取特殊尺寸（AP）
      Map<String,List<RMS_Size_Mapping__c>> sizeMap =new Map<String,List<RMS_Size_Mapping__c>>();

      for(RMS_Size_Mapping__c item:[
          select Id,BU__c,Material__c,Asia__c,US__c from RMS_Size_Mapping__c
      ]) {            
          if(sizeMap.containsKey(item.Material__c)) {
              sizeMap.get(item.Material__c).add(new RMS_Size_Mapping__c(Id=item.Id,Asia__c=item.Asia__c,US__c=item.US__c));
          } else {
              List<RMS_Size_Mapping__c> slist = new List<RMS_Size_Mapping__c>();
              slist.add(new RMS_Size_Mapping__c(Id=item.Id,Asia__c=item.Asia__c,US__c=item.US__c));
              sizeMap.put(item.Material__c, slist);
          }
      }

      for(String material:sizeMap.keySet()){
              for(RMS_Size_Mapping__c item:sizeMap.get(material)){
          String key =material+item.US__c;
          String value = item.Asia__c;
          asiaUSMap.put(key,value);
          }
      }

  }

  /** 检查CSV中该行的值 */
  private Boolean checkCsvValues(RMS_CSV_Iterator.OneLineInfo tr) {
    Boolean isOk = true;

    if (String.isBlank(tr.get('Material code'))) {
      //RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): [Material Code]不能为空');
      throw new RMS_CommonUtil.RMSException(
        '(行' +
        tr.lineIndex +
        '): [Material Code]不能为空'
      );
      //isOk = false;
    }
    if (String.isBlank(tr.get('Size'))) {
      //RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): [Size]不能为空');
      throw new RMS_CommonUtil.RMSException(
        '(行' +
        tr.lineIndex +
        '): [Size]不能为空'
      );
      //isOk = false;
    }
    return isOk;
  }

  /** 结束 */
  public void finish(Database.BatchableContext context) {
  }

 
  class InspectInfo{
    Map<String,RTV_Order_Inspection__c> inspectMap = new Map<String,RTV_Order_Inspection__c>();
    Map<String, List<Decimal>> actualMaps = new Map<String, List<Decimal>>();
    Map<String, List<String>> remarkMaps = new Map<String, List<String>>();
  }
}
