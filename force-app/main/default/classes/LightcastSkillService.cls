public with sharing class LightcastSkillService {

    
    private static final String SKILLS_URL = 'callout:Lightcast/skills/versions/latest/skills';

    @AuraEnabled(cacheable=true)
    public static List<String> fetchSkills(String query) {
        List<String> results = new List<String>();

        try {
            // Prepare HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SKILLS_URL + '?q=' + EncodingUtil.urlEncode(query, 'UTF-8') + '&limit=10');
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');

            // Send request via Named Credential
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (responseBody.containsKey('data')) {
                    List<Object> skills = (List<Object>) responseBody.get('data');
                    for (Object s : skills) {
                        Map<String, Object> skillData = (Map<String, Object>) s;
                        if (skillData.containsKey('name')) {
                            results.add((String) skillData.get('name'));
                        }
                    }
                }
            } else {
                System.debug('Lightcast API error: ' + res.getStatusCode() + ' ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug('Error fetching Lightcast skills: ' + e.getMessage());
        }

        return results;
    }
}