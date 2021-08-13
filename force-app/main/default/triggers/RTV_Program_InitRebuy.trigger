trigger RTV_Program_InitRebuy on RTV_Program__c (before insert, before update) {

    for(RTV_Program__c pro:Trigger.new)
    {
        // DTC场合 Rebu默认未选择
        if(pro.IsDTC__c){
            pro.Rebuy__c = pro.DTC_Rebuy__c;
        }
    }
    
}