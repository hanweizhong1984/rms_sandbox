@IsTest(isParallel=true)
public class Test_RMS_CSV_Iterator {
    @isTest
    public static void test() {
        Blob csvBody = Blob.valueof('\rKEY1\rxxx\rxxx');
        
        // 异常
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(csvBody, 'gb2312');
        try {
            csvIter.skipTitleLine(new String[]{'KEY0'});
        }catch(Exception err){
        }
        
        // 正常
        csvIter = new RMS_CSV_Iterator(csvBody, 'UTF-8');
        csvIter.skipTitleLine(new String[]{'KEY1'});
        System.debug(csvIter.headerLine);
        
        while (csvIter.next()) {
            // 获取当前line为map
            csvIter.getLine();
            csvIter.getLineAsList();
            csvIter.getLineAsMap();
            
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            tr.getDecimal('KEY1', 0);
            //tr.getDecimal('xxxx', 0);
            tr.put('KEY1', '3');
            tr.toString();
            tr.values();
        }
        
        RMS_CSV_Iterator.BatchIterable batchI = new RMS_CSV_Iterator.BatchIterable(csvIter);
        batchI.Iterator();
    }
}