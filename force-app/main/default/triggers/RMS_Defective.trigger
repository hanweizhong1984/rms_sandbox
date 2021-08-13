trigger RMS_Defective on RTV_Defective__c (before insert,after insert,before update) 
{
    //获取全局类型
    Map<String, RecordType> allTypes = RMS_CommonUtil.getRecordTypes('RTV_Defective__c');
    //当前DEF Program
    RTV_Defective__c defective = new RTV_Defective__c();
    //当前DEF Program Id
    Set<Id> defId = new Set<Id>();
    Set<Id> defacapId = new Set<Id>();
    //需要更新的Order列表
    List<RTV_Order__c> updateOrder = new List<RTV_Order__c>();

    List<RTV_Defective__c> requestList = new List<RTV_Defective__c>();
    List<RTV_Defective__c> ftwrequestList = new List<RTV_Defective__c>();

    /**类型转换 */
    if(Trigger.isAfter)
    {
        for(RTV_Defective__c def:Trigger.new)
        {
            if(Trigger.isInsert)
            {
                defective = def;
            }   
        }
    } 

    /**
     * 新建，更新program前
     * */
    if(Trigger.isBefore) {

        for(RTV_Defective__c request : Trigger.new) {
            //新增前
            if(Trigger.isInsert)
            {
                // 修改defective名称
                request.Defective_Auth_Code__c = RMS_CommonUtil.defect_getCode();
                if(request.Type__c == 'ACCAPP')
                {
                    // 记录新增的ACCAPP defective
                    requestList.add(request);
                }
                if(request.Type__c == 'FTW')
                {
                    // 记录新增的FTW defective
                    ftwrequestList.add(request);
                }
            }
            //更新前
            if(Trigger.isUpdate)
            {   
                RTV_Defective__c oldDef = Trigger.oldMap.get(request.id);
                if(request.Status__c == 'Off Policy' && oldDef.Status__c =='Pending')
                {
                    request.RecordTypeId = allTypes.get('RTV Defective Off Policy').id;
                    if(request.Type__c == 'FTW')
                    {
                        defId.add(request.id);
                    }
                    if(request.Type__c == 'ACCAPP')
                    {
                        defacapId.add(request.id);
                    }
                }
                if(request.Status__c == 'Pending')
                {
                    request.RecordTypeId = allTypes.get('RTV Defective Ready').id;
                }
                if((request.Refresh__c == true && oldDef.Refresh__c == false)
                || request.Start_Date__c != oldDef.Start_Date__c
                || request.End_Date__c != oldDef.End_Date__c)
                {
                    defective = request;
                    defective.Refresh__c = false;
                }
            }
        }
    }
    /**
     * 当DEF Program Off Policy时，更新Order Off Policy状态
     */
    if(!defId.isEmpty())
    {
        for(RTV_Order__c order:[SELECT ID,Name,Off_Policy__c 
                                FROM RTV_Order__c 
                                WHERE RTV_Defective_FW__c IN : defId])
        {
            RTV_Order__c newOrder = new RTV_Order__c();
            newOrder.id = order.id;
            newOrder.Off_Policy_FW__c = true;
            updateOrder.add(newOrder);
        }

    }
    if(!defacapId.isEmpty())
    {
        for(RTV_Order__c order:[SELECT ID,Name,Off_Policy__c 
                                FROM RTV_Order__c 
                                WHERE RTV_Defective__c IN:defacapId])
        {
            RTV_Order__c newOrder = new RTV_Order__c();
            newOrder.id = order.id;
            newOrder.Off_Policy__c = true;
            updateOrder.add(newOrder);
        }
    }
    /**
     * 更新Order列表
     */
    if(defective!=null)
    {
        //首先删除Program下的所有Order
        List<RTV_Order__c> delOrder = new List<RTV_Order__c>();
        for(RTV_Order__c order:[SELECT ID,RTV_Defective_FW__c,RTV_Defective__c 
                                FROM RTV_Order__c 
                                WHERE RTV_Defective_FW__c = :defective.id 
                                OR RTV_Defective__c = :defective.id])
        {
            RTV_Order__c newOrder = new RTV_Order__c();
            newOrder.id = order.id;
            if(defective.Type__c == 'FTW')
            {
                newOrder.RTV_Defective_FW__c = null;
            }
            if(defective.Type__c == 'ACCAPP')
            {
                newOrder.RTV_Defective__c = null;
            }
            delOrder.add(newOrder);
        }
        if(!delOrder.isEmpty())
        {
            update delOrder;
        }
        //重新搜索符合条件的Order
        List<RTV_Order__c> orderList = [
            SELECT Id,Name,	RTV_DEF_Summary__c,	From_TakeBack_Order__c,
                    Actual_Date_Of_WSL_Confirmed__c ,Actual_Date_Of_WSL_Inbound__c,
                    Off_Policy_FW__c,Off_Policy__c
            FROM RTV_Order__c 
            WHERE (Off_Policy__c = false OR Off_Policy_FW__c = false)
            AND IsDTC__c = false
        ];
        for(RTV_Order__c order:orderList)
        {
            //DEF ORDER
            if(order.RTV_DEF_Summary__c != null && order.From_TakeBack_Order__c == null)
            {
                if(order.Actual_Date_Of_WSL_Confirmed__c >= defective.Start_Date__c && order.Actual_Date_Of_WSL_Confirmed__c <= defective.End_Date__c)
                {
                    RTV_Order__c newOrder = new RTV_Order__c();
                    newOrder.id = order.id;
                    if(defective.Type__c == 'FTW' && order.Off_Policy_FW__c == false)
                    {
                        newOrder.RTV_Defective_FW__c = defective.id;
                    }
                    if(defective.Type__c == 'ACCAPP' && order.Off_Policy__c == false)
                    {
                        newOrder.RTV_Defective__c = defective.id;
                    }
                    updateOrder.add(newOrder);
                }
            }
            //TB ORDER
            if(order.RTV_DEF_Summary__c != null && order.From_TakeBack_Order__c != null)
            {
                if(order.Actual_Date_Of_WSL_Inbound__c >= defective.Start_Date__c && order.Actual_Date_Of_WSL_Inbound__c <= defective.End_Date__c)
                {
                    RTV_Order__c newOrder = new RTV_Order__c();
                    newOrder.id = order.id;
                    if(defective.Type__c == 'FTW' && order.Off_Policy_FW__c == false)
                    {
                        newOrder.RTV_Defective_FW__c = defective.id;
                    }
                    if(defective.Type__c == 'ACCAPP' && order.Off_Policy__c == false)
                    {
                        newOrder.RTV_Defective__c = defective.id;
                    }
                    updateOrder.add(newOrder);
                }
            }
        }
    }
    //更新Order
    if(!updateOrder.isEmpty())
    {
        update updateOrder;
    }
    /**时间判断 */
    if(Trigger.isBefore) {
        List<RTV_Defective__c> requestList = new List<RTV_Defective__c>();
        List<RTV_Defective__c> ftwrequestList = new List<RTV_Defective__c>();
        //新增前
        for(RTV_Defective__c request : Trigger.new) {
            if(Trigger.isInsert)
            {
                // 修改defective名称
                request.Defective_Auth_Code__c = RMS_CommonUtil.defect_getCode();
                if(request.Type__c == 'ACCAPP')
                {
                    // 记录新增的ACCAPP defective
                    requestList.add(request);
                }
                else 
                {
                    // 记录新增的FTW defective
                    ftwrequestList.add(request);
                }
            }
            if(Trigger.isUpdate)
            {   
                //记录修改时间的AC/AP Defective
                RTV_Defective__c oldRequest = Trigger.oldMap.get(request.id);
                if((oldRequest.Start_Date__c != request.Start_Date__c
                || oldRequest.End_Date__c != request.End_Date__c)
                && request.Type__c == 'ACCAPP'
                )
                {
                    requestList.add(request);
                }
                //记录修改时间的FTW Defective
                if((oldRequest.Start_Date__c != request.Start_Date__c
                || oldRequest.End_Date__c != request.End_Date__c)
                && request.Type__c == 'FTW'
                )
                {
                    ftwrequestList.add(request);
                }
            }
        }
        //判断时间
        if(requestList.size()>0)
        {
            //ACCAPP类型中当前最大截止时间
            AggregateResult oldRequest = [
                SELECT MAX(End_Date__c) End_Date__c
                FROM RTV_Defective__c
                WHERE Type__c='ACCAPP'
                AND Status__c='Pending'
            ];
            // 检查日期
            for(RTV_Defective__c request:requestList)
            {
                if((Date)oldRequest.get('End_Date__c') >= request.Start_Date__c) {
                    request.addError('Please off policy the last program!');
                }
            }            
        }
        if(ftwrequestList.size()>0)
        {
            //FTW类型中当前最大截止时间
            AggregateResult oldFTWRequest = [
                SELECT MAX(End_Date__c) End_Date__c
                FROM RTV_Defective__c
                WHERE Type__c='FTW'
                AND Status__c='Pending'
            ];

            // 检查日期
            for(RTV_Defective__c request:ftwrequestList)
            {
                if((Date)oldFTWRequest.get('End_Date__c') >= request.Start_Date__c) {
                    request.addError('Please off policy the last program!');
                }
            }

        }
    }
}