@IsTest(isParallel=true)
public class Test_RTV_Order_UploadInspectCtrl {
    @isTest
    public static void test() {
        // masterdata.soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxx';
        insert soldto;
        
        // masterdata.tradingterm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        tradeTerm.Name = soldto.Name+'2020';
        tradeTerm.TT_APP_ACC__c = 0.9;
        tradeTerm.TT_FTW_EG__c = 0.9;
        tradeTerm.TT_FW_Seasonal__c = 0.9;
        tradeTerm.Year__c = 2020;
        insert tradeTerm;
        
        RMS_Product__c product = new RMS_Product__c();
        product.Material_Code__c = '[material]';
        product.BUCN__c = 'APP';
        product.Season_Code_CN__c = '20Q1';
        insert product;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Status__c = 'Delivered';
        order.Name = '000001';
        order.Order_Auth_Code__c = order.Name;
        order.Sold_To__c = soldto.Id;
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = '[material]';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        insert item;
        
        item = [SELECT LF_Order_Auth_Code__c FROM RTV_Order_Item__c WHERE id = :item.Id];
        
        // ----------------------------
        // 开始测试
        // ----------------------------
        ApexPages.currentPage().getParameters().put('orderId', order.Id);
        RTV_Order_UploadInspectCtrl ctrl = new RTV_Order_UploadInspectCtrl();
        ctrl.cancel();
        
        // 空文件
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        
        // 错误:禁止新增
        ctrl.createItemIfNotFound = false;
        ctrl.fileUploadBody = Blob.valueof('\r'
            + '退货授权号,Material code,Style,Color,Size,季节码,申请数量,实收,差异,A,B,C,D,Reason code\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,11,20Q1,3,3,0,1,1,1,1,A\r'
        );
        ctrl.upload();
        
        // 错误
        ctrl.createItemIfNotFound = true;
        ctrl.fileUploadBody = Blob.valueof('\r'
            + '退货授权号,Material code,Style,Color,Size,季节码,申请数量,实收,差异,A,B,C,D,Reason code\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,11,季节码,3,3,0,1,1,1,1,A\r'
            + item.LF_Order_Auth_Code__c + ',[error],style,color,XL,20Q1,3,3,0,1,1,1,1,D\r'
        );
        ctrl.upload();
        
        // 正确
        ctrl.createItemIfNotFound = true;
        ctrl.fileUploadBody = Blob.valueof('\r'
            + '退货授权号,Material code,Style,Color,Size,季节码,申请数量,实收,差异,A,B,C,D,Reason code\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,A\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B1\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B2\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B3\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B4\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B5\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B6\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,B7\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C1\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-1\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-2\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-3\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-4\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-5\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-6\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,C2-7\r'
            + item.LF_Order_Auth_Code__c + ',[material],style,color,XL,20Q1,3,3,0,1,1,1,1,D\r'
        );
        ctrl.upload();
        
        // 更新
        ctrl.upload();
    }
}