public with sharing class RTV_Defective_SellingPrice_Batch implements Database.Batchable<SObject>, Database.Stateful {
    
    /** 参数：目标summaryId */
    private final Id defSummaryId;
    
    /** 参数: 订单范围 */
    public final Boolean isFromTakeback;

    /** 参数：税率*/
    private Decimal TaxRate;
    
    /** 全局list：所有的season信息 */
    private final Map<String, RMS_SP_Season_Code__c> seasonCodeMap;
    
    /** 单个order的统计信息 */
    public class OrderInfo {
        // 当前order
        public RTV_Order__c order;
        
        // 当前Order的Item列表
        public Map<RTV_Order_Item__c,List<String>> orderItemMap = new Map<RTV_Order_Item__c,List<String>>();
        
        // MaterialCode集合
        public Set<String> materialCodes = new Set<String>();
        
        // MaterialCode集合(常青款)
        public List<String> ftwCoreList = new List<String>();
        
        // 各个Season的TradingTerm
        public Map<String, RMS_TradingTerm__c> tradingTerms = new Map<String, RMS_TradingTerm__c>();
        
        // 出货记录
        public Map<String,List<RTV_SellingPrices__b>> sellingPriceMap = new Map<String,List<RTV_SellingPrices__b>>();
        
        // 出货记录(Sold To)
        public Map<String, List<RTV_SellingPrices__b>> sellingPriceSTMap = new Map<String, List<RTV_SellingPrices__b>>();
        
        // 出货记录的Key：Material Code + Season Code
        public List<String> sellingKeys = new List<String>();
        
        // 当前遍历的item是否需要检查soldto的Selling记录？
        public Boolean isNeedSoldToSelling = false;
        
        // 待更新items
        public List<RTV_Order_Item__c> updateItems = new List<RTV_Order_Item__c>();
        
        public OrderInfo(RTV_Order__c order) {
            this.order = order;
        }
    }
    
    /** 构造方法 */
    public RTV_Defective_SellingPrice_Batch(Id defSummaryId, Decimal TaxRate, Boolean isFromTakeback) {
        this.defSummaryId = defSummaryId;
        this.TaxRate = TaxRate;
        this.isFromTakeback = isFromTakeback;
        
        // 获取所有的SellingSeasoncode
        this.seasonCodeMap = new Map<String, RMS_SP_Season_Code__c>();
        for(RMS_SP_Season_Code__c season: [SELECT NAME, TaxRate__c FROM RMS_SP_Season_Code__c]) {
            seasonCodeMap.put(season.name, season);
        }
    }
    
    /** 开始 */
    public Database.QueryLocator start(Database.BatchableContext info){
        if (this.isFromTakeback) {
            return Database.getQueryLocator([
                SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name
                FROM RTV_Order__c 
                WHERE Status__c = 'Insp Wait Approval'
                AND RTV_DEF_Summary__c = :this.defSummaryId
                AND From_Takeback_Order__c != null
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, Name, Sold_To__r.Name, Ship_To__r.Name
                FROM RTV_Order__c 
                WHERE Status__c = 'Insp Wait Approval'
                AND RTV_DEF_Summary__c = :this.defSummaryId
                AND From_Takeback_Order__c = null
                AND Insp_CS_Approve_Time__c = null //必须在CS审批前Mapping
            ]);
        }
    }
    
    /** 执行 */
    public void execute(Database.BatchableContext info, List<RTV_Order__c> orders){
        // 一次只处理1条order（执行batch时请设置参数为1）
        OrderInfo orderInfo = new OrderInfo(orders[0]);

        
        // 遍历item，统计信息
        for (RTV_Order_Item__c item: [
            SELECT id,Material_Code__c,MSRP__c,Season_Code_CN__c,BU_2__c,RTV_Order__r.Ship_To__c,RTV_Order__r.Sold_To__c,Inspect_QTY_A__c,Inspect_QTY_B__c,Inspect_QTY_D__c
            FROM RTV_Order_Item__c 
            WHERE RTV_Order__c = :orderInfo.order.id
        ]) {
            // 统计item的Season范围
            List<String> scList = new SeasonCodeComputer().fourSeason(item.Season_Code_CN__c, seasonCodeMap.KeySet());
            orderInfo.orderItemMap.put(item, scList);
            
            // 统计 Material_Code__c + seasonCode
            for(String seasonCode:scList) {
                orderInfo.sellingKeys.add(item.Material_Code__c + seasonCode);
            }
            // 统计 Material_Code__c
            orderInfo.materialCodes.add(item.Material_Code__c);
        }
        
        // 检索master表信息
        queryProductFTW(orderInfo);
        querySeasonalTradingTerm(orderInfo);
        
        // 检索selling信息
        querySellingPrice(orderInfo);
        
        // 遍历OrderItem
        for(RTV_Order_Item__c orderItem: orderInfo.orderItemMap.keySet())
        {
            // 查找该item在各个季度中是否有Selling记录
            String seasonCode = isSellingPrice(orderInfo, orderItem);
            if(seasonCode == null)
            {
                orderItem.Selling_Unit_Price__c = 0;
                orderItem.Selling_Type__c = 'Not Found';
                orderItem.Selling_Season__c = orderItem.Season_Code_CN__c;
                
                // 获取该season的税率
                if(this.TaxRate == 0)
                {
                    RMS_SP_Season_Code__c spSeason = this.seasonCodeMap.get(orderItem.Selling_Season__c);
                    if (spSeason == null) {
                        throw new RMS_CommonUtil.RMSException('系统中未找到季节（'+orderItem.Selling_Season__c+'）的税率');
                    }
                    this.TaxRate = spSeason.TaxRate__c;
                }
                orderItem.SP_TaxRate__c = this.TaxRate;
                orderInfo.updateItems.add(orderItem);
                continue;
            }
            //检查selling price是否满足条件  
            checkSellingPrice(orderInfo, seasonCode, orderItem);

            orderInfo.updateItems.add(orderItem);
        }

        // 更新item
        if(!orderInfo.updateItems.isEmpty()) {
            update orderInfo.updateItems;
        }
    }
    
    /** 检索常青款的product */
    private void queryProductFTW(OrderInfo orderInfo) {
        for(RMS_FTW_Core_List__c ftwCore:[SELECT NAME FROM RMS_FTW_Core_List__c WHERE Name IN :orderInfo.materialCodes]) {
            orderInfo.ftwCoreList.add(ftwCore.NAME);
        }
    }
    
    /** 检索各季度的tradingTerm */
    private void querySeasonalTradingTerm(OrderInfo orderInfo) {
        for (RMS_TradingTerm__c tt: [
            SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name 
            FROM RMS_TradingTerm__c
        ]) {
            orderInfo.tradingTerms.put(tt.Name, tt);
        }
    }
    
    /**
     * 查找出货记录表
     */
    public void querySellingPrice(OrderInfo orderInfo)
    {
        // 检索shipto级别的selling信息
        for(RTV_SellingPrices__b sellingPrice: [
            SELECT ID,Ship_To_Code__c,Sold_To_Code__c,MSRP__c,BU__c,Season_Code__c,Selling_Price__c,Material_Code__c,MCSC__c 
            FROM RTV_SellingPrices__b 
            WHERE MCSC__c IN :orderInfo.sellingKeys 
            AND Sold_To_Code__c = :orderInfo.order.Sold_To__r.Name
            AND Ship_To_Code__c = :orderInfo.order.Ship_To__r.Name
        ]) {
            String key = sellingPrice.MCSC__c + sellingPrice.Ship_To_Code__c;

            // map key:string values: list
            if(orderInfo.sellingPriceMap.containsKey(key))
            {
                orderInfo.sellingPriceMap.get(key).add(sellingPrice); 
            }
            else 
            {
                List<RTV_SellingPrices__b> sellingValues = new List<RTV_SellingPrices__b>();
                sellingValues.add(sellingPrice);
                
                orderInfo.sellingPriceMap.put(key,sellingValues);
            }
            
        }
        
        // 检索soldto级别的selling信息
        for(RTV_SellingPrices__b sellingPrice: [
            SELECT ID,Ship_To_Code__c,Sold_To_Code__c,MSRP__c,BU__c,Season_Code__c,Selling_Price__c,Material_Code__c,MCSC__c 
            FROM RTV_SellingPrices__b 
            WHERE MCSC__c IN :orderInfo.sellingKeys
            AND Sold_To_Code__c = :orderInfo.order.Sold_To__r.Name
        ])
        {
            String key = sellingPrice.MCSC__c + sellingPrice.Sold_To_Code__c;
 
            // map key:string values: list
            if(orderInfo.sellingPriceSTMap.containsKey(key))
            {
                orderInfo.sellingPriceSTMap.get(key).add(sellingPrice); 
            }
            else 
            {
                List<RTV_SellingPrices__b> sellingValues = new List<RTV_SellingPrices__b>();
                sellingValues.add(sellingPrice);
                
                orderInfo.sellingPriceSTMap.put(key, sellingValues);
            } 
        }

    }
    
    /**
     * 查找出货记录表
     * orderItem：对应OrderItem
     * scList:一年周期的季度集合
     */
    public String isSellingPrice(OrderInfo orderInfo, RTV_Order_Item__c orderItem)
    {
        orderInfo.isNeedSoldToSelling = false;
        
        // 遍历该item的selling季节范围
        for(String seasonCode: orderInfo.orderItemMap.get(orderItem)) {
            // 检查shipto级别selling中是否有记录
            String keyCode = orderItem.Material_Code__c + seasonCode + orderInfo.order.Ship_To__r.Name;
            if(orderInfo.sellingPriceMap.containsKey(keyCode))
            {
                return seasonCode;
            }
            // 检查soldto级别selling中是否有记录
            String keySTCode = orderItem.Material_Code__c + seasonCode + orderInfo.order.Sold_To__r.Name;
            if(orderInfo.sellingPriceSTMap.containsKey(keySTCode))
            {
                orderInfo.isNeedSoldToSelling = true;
                return seasonCode;
            }
        }
        return null;
    }
    
    /**
     * 获得Selling Price
     */
    public void checkSellingPrice(OrderInfo orderInfo, String seasonCode, RTV_Order_Item__c orderItem) {
        // 获取该season的TradingTerm
        Decimal tradingTerm = getSellingTradingTerm(orderInfo, seasonCode, orderItem);
        
        // 获取该season的税率
        if(this.TaxRate == 0)
        {
            this.TaxRate = this.seasonCodeMap.get(seasonCode).TaxRate__c;
        }
        
        //正价
        Decimal positivePrice = 0;
        //PVD/EPR价格
        Decimal pvdeprPrice = 0;
        Decimal miniMum = 100000;
        String keyCode = null;
        
        Map<String, List<RTV_SellingPrices__b>> spMap = new Map<String, List<RTV_SellingPrices__b>>();
        List<Decimal> disList = new List<Decimal>();
        
        //shipto维度的sellingprice合集
        if(orderInfo.isNeedSoldToSelling == false)
        {
            spMap = orderInfo.sellingPriceMap;
            keyCode = orderItem.Material_Code__c + seasonCode + orderInfo.order.Ship_To__r.Name;
        }
        //sold to维度的sellingprice合集
        else 
        {
            spMap = orderInfo.sellingPriceSTMap;
            keyCode = orderItem.Material_Code__c + seasonCode + orderInfo.order.Sold_To__r.Name;
        }

        
        for(RTV_SellingPrices__b sp: spMap.get(keyCode))
        {   
            if (sp.MSRP__c == null || sp.MSRP__c == 0) {
                throw new RMS_CommonUtil.RMSException('Error MSRP in selling data:' 
                    + ' Season=' + sp.Season_Code__c 
                    + ', Ship-to=' + sp.Ship_To_Code__c 
                    + ', Sold-to=' + sp.Sold_To_Code__c 
                    + ', Material Code=' + sp.Material_Code__c
                    + ', MSRP=' + sp.MSRP__c); 
            }
            
            Decimal dis = ((sp.Selling_Price__c * this.TaxRate) /sp.MSRP__c).setScale(2, System.RoundingMode.HALF_UP);

            if(dis.format() != tradingTerm.format())
            {
                disList.add(dis);
                pvdeprPrice = (sp.MSRP__c/this.TaxRate*dis).setScale(2, System.RoundingMode.HALF_UP);
            }
            else 
            {
                // positivePrice = sp.Selling_Price__c;
                positivePrice = (sp.MSRP__c/this.TaxRate*dis).setScale(2, System.RoundingMode.HALF_UP);
            }
            //取得最小数据
            if(sp.Selling_Price__c < miniMum)
            {
                miniMum = (sp.MSRP__c/this.TaxRate*dis).setScale(2, System.RoundingMode.HALF_UP);
            }
        }
       

        //全部正价
        if(disList.size() == 0)
        {
            orderItem.Selling_Unit_Price__c = positivePrice;
            orderItem.Selling_Type__c = '';
        }
        //存在PVD
        if(disList.size() < spMap.get(keyCode).size() && disList.size() != 0)
        {
            orderItem.Selling_Type__c = '';
            orderItem.Selling_Unit_Price__c = positivePrice;
        }
        //全部PVD
        if(disList.size() == spMap.get(keyCode).size())
        {
            //折扣价格相同
            if(new Set<Decimal>(disList).size() == 1)
            {  
                orderItem.Selling_Type__c = 'T.B.D(There Is A Minimum Selling Price:'+pvdeprPrice+')';
                orderItem.Selling_Unit_Price__c = 0;
            }
            //折扣价格不相同
            else 
            {
                orderItem.Selling_Unit_Price__c = 0;
                orderItem.Selling_Type__c = 'T.B.D(There Is A Minimum Selling Price:' + miniMum.format()+')';
            } 
        } 
        orderItem.SP_TaxRate__c = this.TaxRate;
        orderItem.Selling_Season__c = seasonCode;
    }
    
    /**
     * 获取目标Selling季节的TradingTerm
     */
    public Decimal getSellingTradingTerm(OrderInfo orderInfo, String seasonCode, RTV_Order_Item__c orderItem) {
        // 解析季节码
        RMS_CommonUtil.SeasonCodeCN season = new RMS_CommonUtil.SeasonCodeCN(seasonCode);

        // 获取目标财年的TradingTerm对象
        RMS_TradingTerm__c tradeTerm = orderInfo.tradingTerms.get(orderInfo.order.Sold_To__r.Name + season.fiscalYear);

        // 判断常青款
        Boolean isFwCore = orderInfo.ftwCoreList.contains(orderItem.Material_Code__c);

        // 获取tradeterm
        Decimal result = RMS_CommonUtil.item_getTradeTerm_DEF(orderItem.BU_2__c, tradeTerm, isFwCore);
        if (result == null) {
            throw new RMS_CommonUtil.RMSException('缺少TradingTerm基础数据: SoldTo=' + orderInfo.order.Sold_To__r.Name + ', 财年=' + season.fiscalYear);
        }
        return result;
    }
    
    /** 季节码计算器 */
    public class SeasonCodeComputer {
        
        /** 前后4个季节码 */
        public List<String> fourSeason(String seasonCode, Set<String> filterSeasonCodes) {
            List<String> sdList = new List<String>();
            // 检查范围
            if(filterSeasonCodes.contains(seasonCode))
            {
                //下一个季度
                String nextSD = this.next(seasonCode);
                //上一个季度
                String beSD = this.before(seasonCode);
                //上上个季度
                String bbeSD = this.before(beSD);
                
                //继续查找上一个季度
                sdList.add(seasonCode);
                sdList.add(beSD);
                
                // 下一个季度在范围内时
                if(filterSeasonCodes.contains(nextSD)) {
                    sdList.add(nextSD);
                    sdList.add(bbeSD);
                }
                // 如果下一个季度不在范围内时，获取上上上个季度
                else {
                    sdList.add(bbeSD);
                    sdList.add(this.before(bbeSD));
                }
            }
            return sdList;
        }
        
        /** 后一个季节码 */
        public String next(String seasonCode) {
            String nextSeasonCode = null;
            //年
            Integer year = Integer.valueOf(seasonCode.substring(0, 2));
            //季度
            Integer quarter = Integer.valueOf(seasonCode.substring(3));
            if(seasonCode.endswith('4')) {
                nextSeasonCode = (year+1).format()+'Q1';
            } else {
                nextSeasonCode = seasonCode.substring(0, 3)+(quarter+1).format();
            }
            return nextSeasonCode;
        }
        
        /** 前一个季节码 */
        public String before(String seasonCode) {
            String beSeasonCode = null;
            //年
            Integer year = Integer.valueOf(seasonCode.substring(0, 2));
            //季度
            Integer quarter = Integer.valueOf(seasonCode.substring(3));
            if(seasonCode.endswith('1')) {
                beSeasonCode = (year-1).format()+'Q4';
            } else {
                beSeasonCode = seasonCode.substring(0, 3)+(quarter-1).format();
            }
            return beSeasonCode;
        }
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext info){
    }
}