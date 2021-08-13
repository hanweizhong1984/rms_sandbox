trigger RMS_Order_Current_Status_QTY on RTV_Order__c (before update,after update) {

    //上传Packing List状态
    Set<Id> pkSum = new Set<Id>();
    //delivery状态
    Set<Id> devSum = new Set<Id>();
    //inspected状态
    Set<Id> insSum = new Set<Id>();
    //更新summary列表
    List<RTV_Summary__c> updateSum = new List<RTV_Summary__c>();

    //更新前
    if(Trigger.isBefore)
    {
        for(RTV_Order__c newOrder:Trigger.new)
        {
            RTV_Order__c oldOrder = Trigger.oldMap.get(newOrder.id);
            //Order状态为Ready或POST To LF,申请数量更新时
            if((newOrder.Status__c == 'POST to LF' || newOrder.Status__c =='Ready')
            && (newOrder.Application_QTY__c != oldOrder.Application_QTY__c))
            {
                //order的动态数量为申请数量
                newOrder.Current_Status_QTY__c = newOrder.Application_QTY__c;
            }
            //Order状态为Delivery,提货数量更新时
            if(newOrder.Status__c == 'Delivered' && newOrder.Delivery_QTY__c != oldOrder.Delivery_QTY__c)
            {
                //order的动态数量为delivery数量
                newOrder.Current_Status_QTY__c = newOrder.Delivery_QTY__c;
            }
            //Order状态为inspected,质检数量更新时
            if(newOrder.Status__c =='Inspected' 
            && (newOrder.Inspect_QTY_A__c != oldOrder.Inspect_QTY_A__c ||
                newOrder.Inspect_QTY_B__c != oldOrder.Inspect_QTY_B__c ||
                newOrder.Inspect_QTY_C__c != oldOrder.Inspect_QTY_C__c ||
                newOrder.Inspect_QTY_D__c != oldOrder.Inspect_QTY_D__c))
            {
                //order的动态数量为Inspected数量合计
                newOrder.Current_Status_QTY__c = (newOrder.Inspect_QTY_A__c
                                                  +newOrder.Inspect_QTY_B__c
                                                  +newOrder.Inspect_QTY_C__c
                                                  +newOrder.Inspect_QTY_D__c);
            }
            if(newOrder.Status__c == 'Completed')
            {
                //order的动态数量为Inbound数量
                newOrder.Current_Status_QTY__c = newOrder.Inbound_QTY__c;
            }
        }
    }
    //更新后
    if(Trigger.isAfter)
    {
        for(RTV_Order__c newOrder:Trigger.new)
        {
            RTV_Order__c oldOrder = Trigger.oldMap.get(newOrder.id);
            //Order状态为Ready或POST To LF,申请数量更新时
            if((newOrder.Status__c == 'POST to LF' || newOrder.Status__c =='Ready')
            && (newOrder.Application_QTY__c != oldOrder.Application_QTY__c)
            && newOrder.Return_Summary__c != null)
            {
                pkSum.add(newOrder.Return_Summary__c);
            }
            //Order状态为Delivery,提货数量更新时
            if(newOrder.Status__c == 'Delivered' 
            && newOrder.Delivery_QTY__c != oldOrder.Delivery_QTY__c 
            && newOrder.Return_Summary__c != null)
            {
                devSum.add(newOrder.Return_Summary__c);
            }
            //Order状态为inspected,质检数量更新时
            if(newOrder.Status__c =='Inspected' 
            && newOrder.Return_Summary__c != null
            && (newOrder.Inspect_QTY_A__c != oldOrder.Inspect_QTY_A__c ||
                newOrder.Inspect_QTY_B__c != oldOrder.Inspect_QTY_B__c ||
                newOrder.Inspect_QTY_C__c != oldOrder.Inspect_QTY_C__c ||
                newOrder.Inspect_QTY_D__c != oldOrder.Inspect_QTY_D__c))
            {
                insSum.add(newOrder.Return_Summary__c);
            }
        }
    }
    /**
     * 申请数量
     */
    if(pkSum.size()>0)
    {
        List<AggregateResult> pkAmount = [SELECT SUM(Application_QTY__c)  Application_QTY__c,
                                            Return_Summary__c ID
                                            FROM RTV_Order__c 
                                            WHERE Return_Summary__c IN :pkSum
                                            Group By Return_Summary__c];
        for(AggregateResult result:pkAmount)
        {
            RTV_Summary__c summary = new RTV_Summary__c();
            summary.ID = (Id)result.get('ID');
            summary.Current_Status_QTY__c = (Decimal)result.get('Application_QTY__c');
            updateSum.add(summary);
        }
    }
    /**
     * 提货数量
     */
    if(devSum.size()>0)
    {
        List<AggregateResult> devAmount = [SELECT SUM(Delivery_QTY__c)  Delivery_QTY__c,
                                            Return_Summary__c ID
                                            FROM RTV_Order__c 
                                            WHERE Return_Summary__c IN :devSum
                                            Group By Return_Summary__c];
        for(AggregateResult result:devAmount)
        {
            RTV_Summary__c summary = new RTV_Summary__c();
            summary.ID = (Id)result.get('ID');
            summary.Current_Status_QTY__c = (Decimal)result.get('Delivery_QTY__c');
            updateSum.add(summary);
        }
    }
    /**
     * 质检数量
     */
    if(insSum.size()>0)
    {
        List<AggregateResult> insAmount = [SELECT SUM(Inspect_QTY_A__c)  Inspect_QTY_A__c,
                                                 SUM(Inspect_QTY_B__c)  Inspect_QTY_B__c,
                                                 SUM(Inspect_QTY_C__c)  Inspect_QTY_C__c,
                                                 SUM(Inspect_QTY_D__c)  Inspect_QTY_D__c,
                                            Return_Summary__c ID
                                            FROM RTV_Order__c 
                                            WHERE Return_Summary__c IN :insSum
                                            Group By Return_Summary__c];
        for(AggregateResult result:insAmount)
        {
            RTV_Summary__c summary = new RTV_Summary__c();
            summary.ID = (Id)result.get('ID');
            summary.Current_Status_QTY__c = (Decimal)result.get('Inspect_QTY_A__c')
                                            +(Decimal)result.get('Inspect_QTY_B__c')
                                            +(Decimal)result.get('Inspect_QTY_C__c')
                                            +(Decimal)result.get('Inspect_QTY_D__c');
            updateSum.add(summary);
        }
    }
    //更新summary
    if(updateSum.size()>0)
    {
        update updateSum;
    }
}