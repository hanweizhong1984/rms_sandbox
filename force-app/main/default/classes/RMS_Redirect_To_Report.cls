public with sharing class RMS_Redirect_To_Report {
    
    // 重定向到report页面
    public Pagereference redirect(){
        String reportName = '';
        String filterStr = '';
        
        // 获取参数
        Integer filterIdx = 0;
        for (String paramKey:  ApexPages.currentPage().getParameters().keySet()) {
            String paramValue = ApexPages.currentPage().getParameters().get(paramKey);
            
            if (paramKey == 'reportName') {
                reportName = paramValue;
            }
            if (paramKey.startsWith('fv')) {
                filterStr += (filterIdx == 0? '?': '&') + paramKey + '=' + paramValue;
                filterIdx ++;
            }
        }
        
        // 检索report
        List<Report> reports = [SELECT Id FROM Report WHERE DeveloperName = :reportName LIMIT 1];
        if (reports.isEmpty()) {
            throw new RMS_CommonUtil.RMSException('Not found report "' + reportName + '"');
        }
        
        // 返回连接
        return new Pagereference('/lightning/r/Report/' + reports[0].Id + '/view' + filterStr);
    }
}