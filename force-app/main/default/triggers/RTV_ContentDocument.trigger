/**
 * Inbound上传文件不可删除
 */
trigger RTV_ContentDocument on ContentDocument (before delete) {
    RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    if (!loginUser.isAdmin || Test.isRunningTest()) {
        Set<Id> cdIds = new Set<Id>();
        for (ContentDocument a : Trigger.old) {            
            cdIds.add(a.Id);
        }

        List<ContentDocumentLink> links = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId IN:cdIds];
        if(links != null){
            // Key:LinkedEntityId
            Map<Id, List<Id>> summaryIds = new Map<Id, List<Id>>();
            for (ContentDocumentLink obj : links) {
                if(summaryIds.containsKey(obj.LinkedEntityId)){
                    summaryIds.get(obj.LinkedEntityId).add(obj.ContentDocumentId);
                }else {
                    summaryIds.put(obj.LinkedEntityId, new List<Id>{obj.ContentDocumentId});
                }
            }
            
            Map<Id,RTV_Summary__c> sumTbMap = new Map<Id,RTV_Summary__c>([SELECT Id FROM RTV_Summary__c WHERE ID IN: summaryIds.keySet()]);
            Map<Id,RTV_DEF_Summary__c> sumDefMap = new Map<Id,RTV_DEF_Summary__c>([SELECT Id FROM RTV_DEF_Summary__c WHERE ID IN: summaryIds.keySet()]);
            
            for (ContentDocument a : Trigger.old) {
                for (Id etId : summaryIds.keySet()) {
                    if((sumTbMap.containsKey(etId) || sumDefMap.containsKey(etId)) && summaryIds.get(etId).contains(a.Id)){
                        a.addError('附件不能删除！');
                    }
                }
            }             
        }
    }
}