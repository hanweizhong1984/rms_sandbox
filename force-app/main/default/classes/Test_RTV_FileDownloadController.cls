@IsTest(isParallel=true)
public class Test_RTV_FileDownloadController {
    @IsTest
    private static void test() {
        if ([SELECT ID FROM RMS_Help__c LIMIT 1].isEmpty()) {
            RMS_Help__c help = new RMS_Help__c();
            help.name = 'ALL';
            insert help;
        }
        
        RTV_FileDownloadController ctrl = new RTV_FileDownloadController();
        System.debug(ctrl.profileList.toString());
        ctrl.profile = 'ALL';
        
        // 空文件
        ctrl.attach();
        
        // 上传
        ctrl.fileName = 'xxx.txt';
        ctrl.fileBody = Blob.valueOf('xxx');
        ctrl.fileDescription = '';
        ctrl.attach();
        
        // 删除文件
        try {
            ApexPages.currentPage().getParameters().put('delfileId', ctrl.attList[0].Id);
            ctrl.deleteFile(); 
        } catch(Exception err) {
        }
        
        // 其它
        try { ctrl.downloadURL(); } catch(Exception err) {}
        try { ctrl.updateFile(); } catch(Exception err) {}
        try { ctrl.saveFile(); } catch(Exception err) {}
    }
}