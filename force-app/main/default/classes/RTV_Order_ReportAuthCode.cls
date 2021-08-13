public with sharing class RTV_Order_ReportAuthCode {

    /** 参数summary */
    public final Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    /** 参数summary */
    public final Id defSummaryId = ApexPages.currentPage().getParameters().get('defSummaryId');
    
    /** 参数 UTF8-BOM（确保excel打开csv不乱吗） */
    public static final String UTF8_BOM ='\uFEFF';

    public String getCsvString() {
        List<RTV_Order__c> orders;
        Boolean isCFS;
        
        // TB Summary
        if (summaryId != null) {
            RTV_Summary__c summary = [
                SELECT RTV_Program__r.IsCFS__c FROM RTV_Summary__c WHERE Id = :this.summaryId
            ];
            orders = [
                SELECT Name, Store_Code__c, Ship_To__r.Name FROM RTV_Order__c
                WHERE Return_Summary__c = :this.summaryId
                AND Status__c = 'Ready'
            ];
            isCFS = summary.RTV_Program__r.IsCFS__c;
        }
        // DEF Summary
        else if (defSummaryId != null) {
            RTV_DEF_Summary__c defSummary = [
                SELECT DTC_Type__c FROM RTV_DEF_Summary__c WHERE Id = :this.defSummaryId
            ];
            orders = [
                SELECT Name, Store_Code__c, Ship_To__r.Name FROM RTV_Order__c
                WHERE RTV_DEF_Summary__c = :this.defSummaryId
                AND Status__c = 'Ready'
            ];
            isCFS = defSummary.DTC_Type__c == 'CFS';
        }
        
        // 标题
        String[] rows = new String[0];
        String[] herder = new String[0];
        herder.add('授权码');
        herder.add('授权码(AP)');
        herder.add('授权码(AC)');
        herder.add('授权码(FW)');
        if(isCFS){
            herder.add('store id');
        }
        else {
            herder.add('ship to');
        }
        rows.add(String.join(herder, ','));
        
        // 明细
        for (RTV_Order__c obj : orders) {
            String[] line = new String[0];
            line.add(obj.Name);
            line.add(obj.Name + 'AP');
            line.add(obj.Name + 'AC');
            line.add(obj.Name + 'FW');
            if(isCFS){
                line.add(obj.Store_Code__c);
            }
            else {
                line.add(obj.Ship_To__r.Name);
            }
            rows.add(String.join(line, ','));
        }

        return UTF8_BOM + String.join(rows,'\n');
    }
}