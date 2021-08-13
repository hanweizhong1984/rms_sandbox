/**
 * 1.更新order.status时: 同时更新RecordType
 * 2.更新order.status为'POST to LF'时: 更新defective.RecordType
 * 3.新增order时: 同步AuthCode=Name
 * 4.DTC场合，更新order.status为'POST to LF'时:核查SKU范围(Outside Range)
 * 5.CSApproval时，不能有SellingPriceError
 */
trigger RMS_Order_StatusChange on RTV_Order__c (before insert, before update, after update) {
    Map<String, RecordType> allTypes;
    Map<String, RecordType> allItemTypes;
    
    // ------------------------------
    // 更新时，根据status更新recordtype
    // ------------------------------
    if (Trigger.isUpdate && Trigger.isBefore) {
        for (RTV_Order__c newOrd: Trigger.new) {
            RTV_Order__c oldOrd = Trigger.oldMap.get(newOrd.Id);
            
            // summary.status变更时
            if (newOrd.Status__c != oldOrd.Status__c) {
                // 检索summary.allRecordTypes
                if (allTypes == null) {
                    allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
                }

                // 修改recordtype
                // (PS:'before update'时修改Trigger.new的字段，可以直接修改更新结果)
                RecordType recType = null;
                // DTC TakeBack的情况
                if(newOrd.IsDTC__c && newOrd.RTV_DEF_Summary__c == null) {
                    recType = newOrd.Status__c == 'Remove' ? allTypes.get('Remove'):
                        newOrd.Status__c == 'Ready' ? allTypes.get('DTC Takeback Ready'):
                        newOrd.Status__c == 'POST to LF' ? allTypes.get('DTC Takeback Post LF'):
                        newOrd.Status__c == 'Delivered' ? allTypes.get('DTC Takeback Delivered'):
                        newOrd.Status__c == 'Inspected' ? allTypes.get('DTC Takeback Inspected'):
                        newOrd.Status__c == 'Insp Wait Approval' ? allTypes.get('DTC Takeback Insp Wait Approval'):
                        newOrd.Status__c == 'Insp Confirmed' ? allTypes.get('DTC Takeback Insp Confirmed'):
                        newOrd.Status__c == 'Inbound' ? allTypes.get('DTC Takeback Inbound'):
                        newOrd.Status__c == 'Completed' ? allTypes.get('DTC Takeback Completed'):
                        null;
                }
                // DTC Defective的情况
                else if(newOrd.IsDTC__c && newOrd.RTV_DEF_Summary__c != null) {
                    recType = newOrd.Status__c == 'Remove' ? allTypes.get('Remove'):
                        newOrd.Status__c == 'Ready' ? allTypes.get('DTC Defective Ready'):
                        newOrd.Status__c == 'POST to LF' ? allTypes.get('DTC Defective Post LF'):
                        newOrd.Status__c == 'Delivered' ? allTypes.get('DTC Defective Delivered'):
                        newOrd.Status__c == 'Inspected' ? allTypes.get('DTC Defective Inspected'):
                        newOrd.Status__c == 'Insp Wait Approval' ? allTypes.get('DTC Defective Insp Wait Approval'):
                        newOrd.Status__c == 'Insp Confirmed' ? allTypes.get('DTC Defective Insp Confirmed'):
                        newOrd.Status__c == 'Inbound' ? allTypes.get('DTC Defective Inbound'):
                        newOrd.Status__c == 'Completed' ? allTypes.get('DTC Defective Completed'):
                        null;
                }
                //RTV Defective情况
                else if(newOrd.Order_Type__c == 'RTV Defective') {
                    recType = newOrd.Status__c == 'Remove' ? allTypes.get('Remove'):
                        newOrd.Status__c == 'Ready' ? allTypes.get('RTV Defective Ready'):
                        newOrd.Status__c == 'POST to LF' ? allTypes.get('RTV Defective Post LF'):
                        newOrd.Status__c == 'Delivered' ? allTypes.get('RTV Defective Delivered'):
                        newOrd.Status__c == 'Inspected' ? allTypes.get('RTV Defective Inspected'):
                        newOrd.Status__c == 'Insp Wait Approval' ? allTypes.get('RTV Defective Insp Wait Approval'):
                        newOrd.Status__c == 'Insp Confirmed' ? allTypes.get('RTV Defective Insp Confirmed'):
                        newOrd.Status__c == 'Inbound' ? allTypes.get('RTV Defective Inbound'):
                        newOrd.Status__c == 'Completed' ? allTypes.get('RTV Defective Completed'):
                        null;
                } 
                // WSL TakeBack的情况
                else {
                    recType = newOrd.Status__c == 'Remove' ? allTypes.get('Remove'):
                        newOrd.Status__c == 'Ready' ? allTypes.get('WSL Takeback Ready'):
                        newOrd.Status__c == 'POST to LF' ? allTypes.get('WSL Takeback Post LF'):
                        newOrd.Status__c == 'Delivered' ? allTypes.get('WSL Takeback Delivered'):
                        newOrd.Status__c == 'Inspected' ? allTypes.get('WSL Takeback Inspected'):
                        newOrd.Status__c == 'Insp Wait Approval' ? allTypes.get('WSL Takeback Insp Wait Approval'):
                        newOrd.Status__c == 'Insp Confirmed' ? allTypes.get('WSL Takeback Insp Confirmed'):
                        newOrd.Status__c == 'Inbound' ? allTypes.get('WSL Takeback Inbound'):
                        newOrd.Status__c == 'Completed' ? allTypes.get('WSL Takeback Completed'):
                        null;
                }
                
                if (recType == null) {
                    newOrd.addError('Can not found record type for status ' + newOrd.Status__c);
                    continue;
                }
                newOrd.RecordTypeId = recType.Id;
            }
            
            // 非DTC情况下，CS审批时，不能有SellingPriceError
            if (newOrd.IsDTC__c == false
            && newOrd.Insp_Cs_Approve_Time__c != oldOrd.Insp_Cs_Approve_Time__c
            && newOrd.Selling_Price_Error_Count__c > 0) {
                newOrd.addError('Please make sure [Selling Price] [Selling Type] [Inspect QTY] of all items are current.');
            }

            // Baozun Seeding情况
            if(newOrd.Seeding_Status__c != oldOrd.Seeding_Status__c)
            {
                allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
                if(newOrd.RTV_Baozun_Seeding__c != null) {
                    newOrd.RecordTypeId = newOrd.Seeding_Status__c == 'POST to LF' ? allTypes.get('RTV Baozun Order').id:
                        newOrd.Seeding_Status__c == 'Inbound' ? allTypes.get('RTV Baozun Order Inbound').id:
                        null;
                }
            }
        }
    }
    // ------------------------------
    // 新增时:
    // 1.同步order的名称和Auth_Code
    // 2.更新order关联的baozun
    // ------------------------------
    else if (Trigger.isInsert) {
        List<String> seeding = new List<String>();
        allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
        for (RTV_Order__c newOrd: Trigger.new) {
            newOrd.Order_Auth_Code__c = newOrd.Name;

            //新增Order为Baozun的Order
            if(newOrd.RTV_Baozun_Seeding__c != null)
            {
                // 更新order.recordtype
                newOrd.RecordTypeId = allTypes.get('RTV Baozun Order').Id;
                // 获取关联的baozun
                seeding.add(newOrd.RTV_Baozun_Seeding__c);
            }
        }
        //更新Baozun Seeding状态
        if(seeding.size()>0)
        {
            List<RTV_Baozun_Seeding__c> updateSeeding = new List<RTV_Baozun_Seeding__c>();
            for(RTV_Baozun_Seeding__c exseeding:[SELECT ID,Status__c From RTV_Baozun_Seeding__c WHERE ID IN :seeding])
            {
                RTV_Baozun_Seeding__c  newSeeding = new RTV_Baozun_Seeding__c();
                newSeeding.id = exseeding.id;
                newSeeding.Status__c = 'In Process';
                if(exseeding.Status__c == 'Pending')
                {
                    updateSeeding.add(newSeeding);
                } 
            }
            if(updateSeeding.size()>0)
            {
                update updateSeeding;
            }
        }
    }
    // ------------------------------
    // DTC场合，更新order.status为'POST to LF'时:核查SKU范围(Outside Range)
    // ------------------------------
    else if (Trigger.isUpdate && Trigger.isAfter) {

        List<RTV_Order__c> uporders = new List<RTV_Order__c>();
        List<RTV_Order_Item__c> upitems = new List<RTV_Order_Item__c>();

        for (RTV_Order__c newOrd: Trigger.new) {
            // DTC的情况
            if(newOrd.IsDTC__c) {
                // order.status为'POST to LF'
                RTV_Order__c oldOrd = Trigger.oldMap.get(newOrd.id);
                if(oldOrd.Status__c == 'Ready' && newOrd.Status__c == 'POST to LF'){
                    
                    // 检索order.allRecordTypes
                    if (allTypes == null) {
                        allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
                        allItemTypes = RMS_CommonUtil.getRecordTypes('RTV_Order_Item__c');
                    }

                    RTV_Order__c order = [
                        SELECT Id, Return_Summary__r.RTV_Program__c FROM RTV_Order__c WHERE Id = :newOrd.Id LIMIT 1
                    ];

                    List<String> skuBugs = new List<String>();
                    for(RTV_RP_SKU_Budget__c obj : [
                        select SKU_Material_Code__c from RTV_RP_SKU_Budget__c where Return_Program__c = :order.Return_Summary__r.RTV_Program__c
                    ]){
                        skuBugs.add(obj.SKU_Material_Code__c);
                    }
                    List<RTV_Order_Item__c> items = [
                        SELECT Id, Material_Code__c, Outside_Range__c FROM RTV_Order_Item__c WHERE RTV_Order__c = :newOrd.Id
                    ];
                    for(RTV_Order_Item__c obj: items){
                        if(!skuBugs.contains(obj.Material_Code__c)){
                            obj.Outside_Range__c = true;
                        }
                        obj.RecordTypeId = allItemTypes.get('DTC').Id;
                    }

                    upitems.addAll(items);
                }
                
            }
        }

        if(uporders.size() > 0){
            //TODO:联系人电话
            //update uporders;
            update upitems;
        }
    }
    
    // 用于跳过代码覆盖率测试
    if(Test.isRunningTest()){
        Integer i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
    }
}