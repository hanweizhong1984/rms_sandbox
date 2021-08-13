@IsTest(isParallel=true)
public class Test_RTV_Order_UploadPackingCtrl {
    @isTest
    public static void test() {
        // setting
        if ([
            SELECT Offset_Of_Kick_Off_To_PTLF__c,
                Offset_Of_PTLF_To_Delivered__c,
                Offset_Of_Delivered_To_Insp__c,
                Offset_Of_Insp_To_CS_Confirm__c,
                Offset_Of_CS_Confirm_To_WSL_Confirm__c,
                Offset_Of_WSL_Confirm_To_Inbound__c,
                Offset_Of_Inbound_To_Completed__c 
            FROM ConverseRMS__c
        ].isEmpty()) {
            insert new ConverseRMS__c(
                Offset_Of_Kick_Off_To_PTLF__c = 1,
                Offset_Of_PTLF_To_Delivered__c = 1,
                Offset_Of_Delivered_To_Insp__c = 1,
                Offset_Of_Insp_To_CS_Confirm__c = 1,
                Offset_Of_CS_Confirm_To_WSL_Confirm__c = 1,
                Offset_Of_WSL_Confirm_To_Inbound__c = 1,
                Offset_Of_Inbound_To_Completed__c = 1
            );
        }
        
        // masterdata.product
        RMS_Product__c product = new RMS_Product__c();
        product.Material_Code__c = '[material]';
        product.Season_Code_CN__c = '20Q1';
        product.BUCN__c = 'APP';
        product.MSRP__c = 123.45;
        insert product;
        
        // masterdata.ussize
        if ([SELECT Id FROM RMS_US_Size__c WHERE BU__c='AP' AND Size__c='29'].isEmpty()) {
            insert new RMS_US_Size__c(BU__c='AP', Size__c='29');
        }
        
        // masterdata.account group
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        insert acgroup;
        
        // masterdata.soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Account_Group__c = acgroup.Id;
        soldto.Name = 'xxxxx';
        insert soldto;
        
        // masterdata.shipto
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '100001';
        shipto.Sold_To_Code__c = soldto.Id;
        shipto.Contact_Pr__c = 'xxxxx';
        shipto.Contact_Tel__c = 'xxxxx';
        shipto.Dely_Addr__c = 'xxxxxxxxx';
        insert shipto;
        
        // masterdata.tradingterm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        tradeTerm.Name = soldto.Name+'2020';
        tradeTerm.TT_APP_ACC__c = 0.9;
        tradeTerm.TT_FTW_EG__c = 0.9;
        tradeTerm.TT_FW_Seasonal__c = 0.9;
        tradeTerm.Year__c = 2020;
        insert tradeTerm;
        
        // program
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        // summarybudget
        RTV_RP_Summary_Budget__c summaryBg = new RTV_RP_Summary_Budget__c();
        summaryBg.Return_Program__c = program.Id;
        summaryBg.Account_Group__c = acgroup.Id;
        summaryBg.Tack_Back_Net__c = 1000000;
        summaryBg.MSRP__c = 100000;
        summaryBg.QTY__c = 1000000;
        insert summaryBg;
        
        // skubudget
        RTV_RP_Sku_Budget__c skuWL = new RTV_RP_Sku_Budget__c();
        skuWL.Return_Program__c = program.Id;
        skuWL.Sku_Material_Code__c = '[material]';
        insert skuWL;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Account_Group__c = acgroup.Id;
        summary.Summary_Budget__c = summaryBg.Id;
        summary.Status__c = 'Pending';
        insert summary;
        
        // shipto-whitelist
        RTV_RP_Ship_To__c shiptoWL = new RTV_RP_Ship_To__c();
        shiptoWL.Sold_To__c = soldto.Id;
        shiptoWL.Ship_To__c = shipto.Id;
        shiptoWL.RTV_Program__c = program.Id;
        shiptoWL.Summary__c = summary.Id;
        shiptoWL.Summary_Budget__c = summaryBg.Id;  
        insert shiptoWL;
        
        // summary -> kickoff
        summary.Status__c = 'Ready';
        update summary;
        
        // 获取 shipto-whitelist
        shiptoWL = [SELECT Id, Order_Auth_Code__c FROM RTV_RP_Ship_To__c WHERE Id = :shiptoWL.Id];
        
        // --------------------
        // 开始test
        // --------------------
        ApexPages.currentPage().getParameters().put('id', summary.Id);
        RTV_Order_UploadPackingCtrl ctrl = new RTV_Order_UploadPackingCtrl();
        ctrl.cancel();
        
        System.debug(ctrl.shipToSelectOptions.toString());
        ctrl.shipToSelected = 'from_csv';
        
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        
        // --------------------------------
        // 错误
        // --------------------------------
        // 错误：空文件
        ctrl.upload();
        
        Test.startTest();
        try {
            ctrl.fileUploadBody = Blob.valueof('\r' +
                '授权码,箱号,货品号,BU,尺寸(美码),尺寸(亚码),季节码,数量,Sold To,Ship To,最早提货日\r' + 
                '--Error------------------'+'AP'+',[box],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[error---],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[material],AP,29,30,??Q?,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + '--error--' + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'FW'+',[box],[material],FW,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r' +
                shiptoWL.Order_Auth_Code__c+'AP'+',[bo2],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r'
            );
            ctrl.upload();
            
            ctrl.fileUploadBody = Blob.valueof('\r' +
                '授权码,箱号,货品号,BU,尺寸(美码),尺寸(亚码),季节码,数量,Sold To,Ship To,最早提货日\r' + 
                shiptoWL.Order_Auth_Code__c+'AP'+',[box],[material],AP,29,30,20Q1,3,' + soldto.Name + ',' + shipto.Name + ',2030/1/1\r'
            );
            ctrl.upload();
            System.debug(ctrl.loadingPercent);
        } 
        finally {
            Test.stopTest();
            ctrl.checkUploadResult();
        }
    }
}