@IsTest(isParallel=true)
public class Test_RMS_CommonUtil {
    @isTest
    public static void test() {
        RMS_CommonUtil.getRecordTypes('RTV_Order__c');
        
        RMS_CommonUtil.summary_getName('programName', 'accountGroupName');
        
        RMS_CommonUtil.order_getCode('aaaa', 'bbbbb', 'xxx');
        RMS_CommonUtil.order_getLFCode('orderAuthCode', 'bu2');
        
        RMS_CommonUtil.defect_getCode('xxx','xxx');
        
        RMS_CommonUtil.item_getName(new RTV_Order_Item__c());
        
        RMS_CommonUtil.item_getUniqueKey('orderAuthCode', new RTV_Order_Item__c());
        RMS_CommonUtil.item_getUniqueKeyDef('orderAuthCode', new RTV_Order_Item__c(), 1, 1);
        
        RMS_CommonUtil.item_Def_IsNoDelivery('无实物退残');
        RMS_CommonUtil.item_Def_IsNoDelivery('xx');
        RMS_CommonUtil.item_Def_IsSepical('特批');
        
        RMS_CommonUtil.item_getBu2('AP');
        RMS_CommonUtil.item_getBu2('AC');
        RMS_CommonUtil.item_getBu2('FW');
        try{
            RMS_CommonUtil.item_getBu2('XXX');
        }catch(Exception err){}
        
        // 计算TradingTerm >>
        RMS_Sold_To__c soldTo = new RMS_Sold_To__c();
        soldTo.TT_APP_ACC__c = 1.2;
        soldTo.TT_FW_Seasonal__c = 1.2;
        soldTo.TT_FTW_EG__c = 1.2;
        
        RTV_Program__c program = new RTV_Program__c();
        program.TaxRate__c = 1.7;
        program.ExRate__c = 0.8;
        program.Discount__c = 0.5;
        
        // 计算TradingTerm
        RMS_TradingTerm__c tradeTerm = new RMS_TradingTerm__c();
        RMS_CommonUtil.item_getTradeTerm_TB('APP', tradeTerm);
        RMS_CommonUtil.item_getTradeTerm_TB('FW', tradeTerm);
        RMS_CommonUtil.item_getTradeTerm_TB('FW', null);
        RMS_CommonUtil.item_getTradeTerm_DEF('APP', tradeTerm, false);
        RMS_CommonUtil.item_getTradeTerm_DEF('FW', tradeTerm, true);
        RMS_CommonUtil.item_getTradeTerm_DEF('FW', tradeTerm, false);
        RMS_CommonUtil.item_getTradeTerm_DEF('FW', null, false);
        
        // 计算Net
        RMS_Product__c pdt = new RMS_Product__c();
        pdt.BUCN__c = 'APP';
        pdt.MSRP__c = 10.2;
        RMS_CommonUtil.item_getNet(pdt, program, 0.7);
        RMS_CommonUtil.item_getNet(pdt, 0.7);
        
        // 字符串转日期
        try{
            RMS_CommonUtil.str2Date('2019/1/29');
        } catch(Exception err){
        }
        try{
            RMS_CommonUtil.str2Date('1/29/2019');
        } catch(Exception err){
        }
        try{
            RMS_CommonUtil.str2Date('2019/1/55');
        } catch(Exception err){
        }
        try{
            RMS_CommonUtil.str2Date('123456');
        } catch(Exception err){
        }
        // str2Decimal
        RMS_CommonUtil.str2Decimal('1', 0);
        RMS_CommonUtil.str2Decimal('xx', 0);
        
        // message
        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.INFO, 'xxx');
        
        // size
        RMS_CommonUtil.size_Us2Asia('XL', 'AP');
        RMS_CommonUtil.size_Asia2Us('L', 'AP');
        RMS_CommonUtil.size_lfUs2Us('10', 'FW');
        
        // ***** shareToRoleSubordinates *****
        try {
            RTV_Order__c order = new RTV_Order__c();
            insert order;
            
            Group grp = [SELECT RelatedId, Type FROM Group WHERE Type = 'RoleAndSubordinates' LIMIT 1];
            
            Map<Id, Id> objAndRoleIds = new Map<Id, Id>();
            objAndRoleIds.put(order.Id, grp.RelatedId);
            
            RMS_CommonUtil.shareToRoleSubordinates(objAndRoleIds, RTV_Order__Share.SObjectType, 'Read');
        } catch(Exception err) {
        }
        // ***** shareToRoleSubordinates *****
        
        new RMS_CommonUtil.LoginUserInfo();
    }
}