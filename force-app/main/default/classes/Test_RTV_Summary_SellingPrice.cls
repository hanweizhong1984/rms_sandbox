@IsTest(isParallel=true)
public class Test_RTV_Summary_SellingPrice {
    @isTest
    public static void test() {
        // 创建soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = '12345';
        insert soldto;
        
        // 创建shipto
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '1234567';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        // 创建summary
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        // 创建order
        RTV_Order__c order = new RTV_Order__c();
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxxx', 'xxx');
        order.Return_Summary__c = summary.Id;
        order.Sold_To__c = soldto.Id;
        order.Ship_To__c = shipto.Id;
        order.Status__c = 'Insp Wait Approval';
        insert order;
        
        // 创建item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'TestProduct';
        item.BU_2__c = 'FW';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Inspect_QTY_A__c = 1;
        item.Inspect_QTY_B__c = 1;
        item.Inspect_QTY_C__c = 1;
        item.Inspect_QTY_D__c = 1;
        insert item;
        
        // 创建tradingTerm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        tradeTerm.Name = soldto.Name;
        tradeTerm.TT_APP_ACC__c = 0.9;
        tradeTerm.TT_FTW_EG__c = 0.9;
        tradeTerm.TT_FW_Seasonal__c = 0.9;
        tradeTerm.Year__c = 2019;
        insert tradeTerm;
        
        // 创建常青款
        RMS_FTW_Core_List__c ftwCore = new RMS_FTW_Core_List__c();
        ftwCore.Name = item.Material_Code__c;
        insert ftwCore;
        
        // 创建seasonCode
        RMS_SP_Season_Code__c season = new RMS_SP_Season_Code__c();
        season.Name = '20Q1';
        season.TaxRate__c = 1.13;
        insert season;
        
        //----------------------------
        // 开始测试
        //----------------------------
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_Summary_SellingPrice ctrl = new RTV_Summary_SellingPrice();
        ctrl.cancel();
        
        Test.StartTest();
        try {
            ctrl.startBatch();
            System.debug(ctrl.loadingPercent);
        } finally {
            Test.StopTest();
            ctrl.checkResult();
        }
        
        //----------------------------
        // 由于测试类中不能创建BigObject
        // 所以单独测试各个方法
        //----------------------------
        RTV_Summary_SellingPrice_Batch batch = new RTV_Summary_SellingPrice_Batch(summary.Id, 0);
        batch.execute(null, new List<RTV_Order__c>{order});
        
        // case：折扣价格相同
        RTV_Summary_SellingPrice_Batch.OrderInfo info = new RTV_Summary_SellingPrice_Batch.OrderInfo(order);
        info.order = order;
        info.order.Sold_To__r = soldto;
        info.tradingTermList = new List<RMS_TradingTerm__c>{tradeTerm};
        info.sellingPriceSTMap.put('TestProduct19Q3' + soldto.Name, new List<RTV_SellingPrices__b>{
            new RTV_SellingPrices__b(
                Material_Code__c='TestProduct',
                Season_Code__c='19Q3',
                Sold_To_Code__c=soldto.Name,
                MSRP__c=123.45,
                Selling_Price__c=55.45
            )
        });
        info.orderItemMap.put(item, new List<String>{'19Q3','19Q4','20Q1','20Q2'});
        batch.isSellingPrice(info, item);
        batch.checkSellingPrice(info, '19Q3', item);
        
        // case：折扣价格不同
        info.sellingPriceSTMap.get('TestProduct19Q3' + soldto.Name).add(
            new RTV_SellingPrices__b(
                Material_Code__c='TestProduct',
                Season_Code__c='19Q3',
                Sold_To_Code__c=soldto.Name,
                MSRP__c=123.45,
                Selling_Price__c=60.45
            )
        );
        batch.checkSellingPrice(info, '19Q3', item);
        
        // case：价格为0
        info.sellingPriceSTMap.get('TestProduct19Q3' + soldto.Name)[0].MSRP__c = 0;
        try {
            batch.checkSellingPrice(info, '19Q3', item);
        } catch(Exception err) {}
    }
}