trigger RMS_DEF_Summary on RTV_DEF_Summary__c (before insert) {
    Map<String, RecordType> sumRecTypes = RMS_CommonUtil.getRecordTypes('RTV_DEF_Summary__c');
    
    // -------------------------------------
    // 设置DefSummary的开放日期区间
    // -------------------------------------
    for (RTV_DEF_Summary__c newSum: Trigger.new) {
        if(String.isNotBlank(newSum.DTC_Type__c)){
            continue;
        }

        try {
            Integer year = Integer.valueOf(newSum.Year__c);
            Integer month = Integer.valueOf(newSum.Month__c);
            newSum.Year__c = String.valueOf(year);
            
            // 申请的开放日= 当月1日
            if (newSum.Apply_Open_Date__c == null) {
                newSum.Apply_Open_Date__c = Date.newInstance(year, month, 1);
            }
            // 申请的关闭日= 当月低
            if (newSum.Apply_Close_Date__c == null) {
                newSum.Apply_Close_Date__c = newSum.Apply_Open_Date__c.addMonths(1).toStartOfMonth().addDays(-1);
            }
            // TakeBack转DEF的开始范围= 上个月16日
            if (newSum.TakeBack_From_Date__c == null) {
                newSum.TakeBack_From_Date__c = newSum.Apply_Open_Date__c.addMonths(-1).toStartOfMonth().addDays(15);
            }
            // TakeBack转DEF的结束范围= ~ 当月15日
            if (newSum.TakeBack_Till_Date__c == null) {
                newSum.TakeBack_Till_Date__c = newSum.Apply_Open_Date__c.toStartOfMonth().addDays(14);
            }
            
            // 申请状态
            newSum.Active_Status__c = 
                Date.today() >= newSum.Apply_Open_Date__c? 'Opening':
                Date.today() > newSum.Apply_Close_Date__c? 'Closed':
                'Not Start';
        }
        catch (Exception err) {
            newSum.addError('Date is not correct: year='+newSum.Year__c+', month='+newSum.Month__c);
        }
            
        // DTC时
        if (newSum.Account_Group_Name__c == '00)CC') {
            // 名称= Year-Month-AccountGroup-CFS
            newSum.Name = newSum.Year__c + '-' + newSum.Month__c + '-' + newSum.Account_Group_Name__c + '-CFS';
            newSum.DTC_Type__c = 'CFS';
            newSum.Sales_Channel__c = 'CFS';
            newSum.RecordTypeId = sumRecTypes.get('DTC').Id;
            
            // 同时创建Digital的DEFSummary
            RTV_DEF_Summary__c digSum = newSum.clone(false, false, false, false);
            digSum.Name = newSum.Year__c + '-' + newSum.Month__c + '-' + newSum.Account_Group_Name__c + '-DIG';
            digSum.DTC_Type__c = 'DIG';
            digSum.Sales_Channel__c = 'DIG';
            digSum.RecordTypeId = sumRecTypes.get('DTC').Id;
            insert digSum;
        }
        // WSL时
        else {
            // 名称= Year-Month-AccountGroup
            newSum.Sales_Channel__c = 'WSL';
            newSum.Name = newSum.Year__c + '-' + newSum.Month__c + '-' + newSum.Account_Group_Name__c;
            newSum.RecordTypeId = sumRecTypes.get('Normal').Id;
        }
    }
    
}