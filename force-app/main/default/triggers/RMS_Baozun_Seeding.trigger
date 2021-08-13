trigger RMS_Baozun_Seeding on RTV_Baozun_Seeding__c (before insert,before update) {

    Map<String, RecordType> allTypes = RMS_CommonUtil.getRecordTypes('RTV_Baozun_Seeding__c');
    Date today = System.today();
    RTV_Baozun_Seeding__c seeding = new RTV_Baozun_Seeding__c();
    
    for(RTV_Baozun_Seeding__c newseeding:Trigger.new)
    {
        //新增操作前
        if(Trigger.isInsert)
        {
            //生成随机授权码
            newseeding.Seeding_Auth_Code__c = 'SEEDBZ' + newseeding.Year__c + String.valueOf(newseeding.Month__c).leftPad(2, '0');
            
            seeding = newseeding;
        }
        if(Trigger.isUpdate)
        {
            RTV_Baozun_Seeding__c oldSeeding = Trigger.oldMap.get(newseeding.id);
            if(newseeding.Status__c == 'In Process')
            {
                newseeding.RecordTypeId = allTypes.get('RTV Baozun Seeding Inprocess').id;
            }
            if(newseeding.Status__c == 'Pending')
            {
                newseeding.RecordTypeId = allTypes.get('RTV Baozun Seeding Pending').id;
            }
            seeding = newseeding;
        }
    }
    /**
     * 限制一个月只能申请一次
     */
    if(seeding != null)
    {
        List<Decimal> month = new List<Decimal>();
        for(RTV_Baozun_Seeding__c exseeding:[SELECT Id,Name,Year__c,Month__c 
                                            FROM RTV_Baozun_Seeding__c 
                                            WHERE Year__c = :seeding.Year__c
                                            And Id != :seeding.id])
        {
            month.add(exseeding.Month__c);
        }

        if(month.contains(seeding.Month__c))
        {
            seeding.addError('Seeding for Month:'+seeding.Month__c+' already exist');
        }
    }
}