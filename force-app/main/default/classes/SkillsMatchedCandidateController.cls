/**
 * @File Name : SkillsMatchedCandidateController.cls
 * @Author    : Ajay Kaurav
 * @Last Modified On : December 26, 2025
 * @Description :
 * Dynamically matches candidates to Job Position based on
 * Skills, Experience, Location and Availability.
 */

public without sharing class SkillsMatchedCandidateController { 
    
    /* =========================================================
       FETCH MATCHED CANDIDATES WITH DYNAMIC MATCH CALCULATION
    ========================================================= */
    @AuraEnabled(cacheable=true)
public static List<CandidateWrapper> getMatchedCandidates(Id jobPositionId) {

    Job_Position__c job = fetchJobPosition(jobPositionId);

    JobSkillContext jobSkillContext = prepareJobSkills(job);

    Set<Id> assignedCandidateIds = fetchAssignedCandidateIds(jobPositionId);

    List<Candidate__c> candidates = fetchCandidates();

    List<CandidateWrapper> result = new List<CandidateWrapper>();

    for (Candidate__c c : candidates) {

        if (!isCandidateEligible(c, assignedCandidateIds)) {
            continue;
        }

        SkillMatchResult skillMatch = calculateCandidateSkillMatch(
            c.Skills__c,
            jobSkillContext.jobSkills
        );

        if (!skillMatch.isMatched) {
            continue;
        }

        MatchScore score = calculateDynamicMatchScore(
            c,
            job,
            skillMatch.matchedCount,
            jobSkillContext.totalJobSkills
        );

        result.add(buildCandidateWrapper(c, skillMatch, score));
    }

    result.sort();
    return result;
}

private static Job_Position__c fetchJobPosition(Id jobPositionId) {
    return [
        SELECT Id, Name,
               Aditional_Skills__c,
               Soft_skills__c,
               Skills_Required__c,
               Minimum_Experience_Required__c,
               Maximum_Experience_Required__c,
               Work_Location__c
        FROM Job_Position__c
        WHERE Id = :jobPositionId WITH USER_MODE
        LIMIT 1
    ];
}


private class JobSkillContext {
    Set<String> jobSkills;
    Integer totalJobSkills;

    JobSkillContext(Set<String> skills, Integer total) {
        jobSkills = skills;
        totalJobSkills = total;
    }
}

private static JobSkillContext prepareJobSkills(Job_Position__c job) {

    Set<String> jobSkills = new Set<String>();
    Integer totalJobSkills = 0;

    List<String> skillFields = new List<String>{
        job.Aditional_Skills__c,
        job.Soft_skills__c,
        job.Skills_Required__c
    };

    for (String field : skillFields) {
        if (String.isBlank(field)) continue;

        for (String s : field.toLowerCase().split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                jobSkills.add(trimmed);
                totalJobSkills++;
            }
        }
    }

    return new JobSkillContext(jobSkills, totalJobSkills);
}


private static Set<Id> fetchAssignedCandidateIds(Id jobPositionId) {

    Set<Id> result = new Set<Id>();

    for (Interview__c iv : [
        SELECT Candidate__c
        FROM Interview__c
        WHERE Job_Position__c = :jobPositionId WITH USER_MODE
    ]) {
        result.add(iv.Candidate__c);
    }

    return result;
}


private static List<Candidate__c> fetchCandidates() {
    return [
        SELECT Id, Name,
               Skills__c,
               Soft_Skills__c,
               Rating__c,
               Total_Experience__c,
               Relevant_Experience__c,
               Current_Location__c,
               Preferred_Location__c,
               Notice_Period__c,
               LastModifiedDate
        FROM Candidate__c
        WHERE Name != null WITH USER_MODE
    ];
}

private static Boolean isCandidateEligible(
    Candidate__c c,
    Set<Id> assignedCandidateIds
) {
    return !assignedCandidateIds.contains(c.Id)
        && String.isNotBlank(c.Skills__c);
}


private class SkillMatchResult {
    Boolean isMatched;
    Set<String> matchedSkills;
    Integer matchedCount;

    SkillMatchResult(Boolean matched, Set<String> skills) {
        isMatched = matched;
        matchedSkills = skills;
        matchedCount = skills.size();
    }
}

private static SkillMatchResult calculateCandidateSkillMatch(
    String candidateSkills,
    Set<String> jobSkills
) {
    Set<String> candidateSkillSet = new Set<String>();

    for (String s : candidateSkills.toLowerCase().split(',')) {
        String trimmed = s.trim();
        if (String.isNotBlank(trimmed)) {
            candidateSkillSet.add(trimmed);
        }
    }

    Set<String> matched = new Set<String>();
    matched.addAll(candidateSkillSet);
    matched.retainAll(jobSkills);

    return new SkillMatchResult(!matched.isEmpty(), matched);
}


private static CandidateWrapper buildCandidateWrapper(
    Candidate__c c,
    SkillMatchResult skillMatch,
    MatchScore score
) {
    return new CandidateWrapper(
        c,
        skillMatch.matchedSkills,
        score.totalScore,
        score.skillMatchPercentage,
        score.experienceMatchPercentage,
        score.locationMatchPercentage,
        score.availabilityMatchPercentage
    );
}




    /* =========================================================
       DYNAMIC MATCH SCORE CALCULATION
       Calculates percentage based on actual available data
    ========================================================= */
    private class MatchScore {
        public Decimal totalScore { get; set; }
        public Decimal skillMatchPercentage { get; set; }
        public Decimal experienceMatchPercentage { get; set; }
        public Decimal locationMatchPercentage { get; set; }
        public Decimal availabilityMatchPercentage { get; set; }
    }

 private static MatchScore calculateDynamicMatchScore(
    Candidate__c candidate,
    Job_Position__c job,
    Integer matchedSkillsCount,
    Integer totalJobSkills
) {
    MatchScore score = new MatchScore();

    score.skillMatchPercentage =
        calculateSkillMatchPercentage(matchedSkillsCount, totalJobSkills);

    score.experienceMatchPercentage =
        calculateExperienceMatch(candidate, job);

    score.locationMatchPercentage =
        calculateLocationMatch(candidate, job);

    score.availabilityMatchPercentage =
        calculateAvailabilityMatch(candidate, job);

    score.totalScore = calculateFinalWeightedScore(score);

    System.debug('Final Match % (Fixed Weight): ' + score.totalScore);

    return score;
}

private static Decimal calculateSkillMatchPercentage(
    Integer matchedSkillsCount,
    Integer totalJobSkills
) {
    if (totalJobSkills == null || totalJobSkills == 0 || matchedSkillsCount == 0) {
        return 0;
    }

    Decimal percentage =
        (Decimal.valueOf(matchedSkillsCount) / totalJobSkills) * 100;

    if (percentage > 100) {
        percentage = 100;
    }

    return percentage.setScale(2);
}

private static Decimal calculateExperienceMatch(
    Candidate__c candidate,
    Job_Position__c job
) {
    if (candidate.Relevant_Experience__c == null ||
        job.Minimum_Experience_Required__c == null) {
        return 0;
    }

    return calculateExperiencePercentage(candidate, job);
}

private static Decimal calculateLocationMatch(
    Candidate__c candidate,
    Job_Position__c job
) {
    if (String.isBlank(job.Work_Location__c)) {
        return 0;
    }

    if (String.isBlank(candidate.Current_Location__c) &&
        String.isBlank(candidate.Preferred_Location__c)) {
        return 0;
    }

    return calculateLocationPercentage(candidate, job);
}

private static Decimal calculateAvailabilityMatch(
    Candidate__c candidate,
    Job_Position__c job
) {
    if (String.isBlank(candidate.Notice_Period__c)) {
        return 0;
    }

    return calculateAvailabilityPercentage(candidate, job);
}

private static Decimal calculateFinalWeightedScore(MatchScore score) {
    Decimal total =
          (score.skillMatchPercentage * 0.60)
        + (score.experienceMatchPercentage * 0.20)
        + (score.locationMatchPercentage * 0.10)
        + (score.availabilityMatchPercentage * 0.10);

    return total.setScale(2);
}



    /* =======================
       EXPERIENCE PERCENTAGE CALCULATION
    ======================== */
    private static Decimal calculateExperiencePercentage(Candidate__c c, Job_Position__c job) {
        Decimal candidateExp = c.Relevant_Experience__c;
        Decimal minExp = job.Minimum_Experience_Required__c;
        Decimal maxExp = job.Maximum_Experience_Required__c;
        
        if (candidateExp == null || minExp == null) {
            return 0;
        }
        
        // Candidate meets minimum requirement
        if (candidateExp >= minExp) {
            // If no maximum specified or candidate is within range
            if (maxExp == null || candidateExp <= maxExp) {
                return 100; // Perfect match
            } else {
                // Overqualified - calculate penalty
                Decimal overage = candidateExp - maxExp;
                // More than 5 years over maximum is significant
                if (overage > 5) {
                    return 70; // 70% match for significantly overqualified
                } else if (overage > 2) {
                    return 80; // 80% match for moderately overqualified
                } else {
                    return 90; // 90% match for slightly overqualified
                }
            }
        } else {
            // Below minimum - calculate based on how close they are
            Decimal ratio = (candidateExp / minExp) * 100;
            // Minimum 10% match if they have some experience
            return Math.max(10, ratio.setScale(2));
        }
    }

    /* =======================
       LOCATION PERCENTAGE CALCULATION
    ======================== */
    private static Decimal calculateLocationPercentage(Candidate__c c, Job_Position__c job) {
        if (String.isBlank(job.Work_Location__c)) {
            return 0;
        }
        
        String jobLocation = job.Work_Location__c.toLowerCase();
        
        // Check preferred location first
        if (String.isNotBlank(c.Preferred_Location__c)) {
            String preferred = c.Preferred_Location__c.toLowerCase();
            if (preferred.equals(jobLocation)) {
                return 100; // Exact match
            }
            
            // Check if locations contain each other
            if (preferred.contains(jobLocation) || jobLocation.contains(preferred)) {
                return 90; // 90% match for containing match
            }
            
            // Check for partial matches (same city name)
            List<String> preferredParts = preferred.split('[ ,-]+');
            List<String> jobParts = jobLocation.split('[ ,-]+');
            
            for (String prefPart : preferredParts) {
                for (String jobPart : jobParts) {
                    if (prefPart.length() > 3 && jobPart.length() > 3 && 
                        prefPart.equals(jobPart)) {
                        return 70; // 70% for same city/area
                    }
                }
            }
        }
        
        // Check current location
        if (String.isNotBlank(c.Current_Location__c)) {
            String current = c.Current_Location__c.toLowerCase();
            if (current.equals(jobLocation)) {
                return 85; // 85% match for exact match in current location
            }
            
            if (current.contains(jobLocation) || jobLocation.contains(current)) {
                return 75; // 75% match for containing match in current location
            }
            
            // Check for partial matches
            List<String> currentParts = current.split('[ ,-]+');
            List<String> jobParts = jobLocation.split('[ ,-]+');
            
            for (String currPart : currentParts) {
                for (String jobPart : jobParts) {
                    if (currPart.length() > 3 && jobPart.length() > 3 && 
                        currPart.equals(jobPart)) {
                        return 60; // 60% for same city/area in current location
                    }
                }
            }
        }
        
        return 0; // No match
    }

    /* =======================
       AVAILABILITY PERCENTAGE CALCULATION
    ======================== */
    private static Decimal calculateAvailabilityPercentage(Candidate__c c, Job_Position__c job) {
        if (String.isBlank(c.Notice_Period__c)) {
            return 0;
        }
        
        Integer candidateDays = parseNoticePeriodToDays(c.Notice_Period__c);
        
        // Job preferred notice period (if specified)
        Integer jobPreferredDays = 0;
        /*if (job.Preferred_Notice_Period__c != null) {
            jobPreferredDays = parseNoticePeriodToDays(job.Preferred_Notice_Period__c);
        }*/
        
        // If job doesn't specify, assume immediate availability is best
        if (jobPreferredDays == 0) {
            // Job wants immediate availability
            if (candidateDays == 0) {
                return 100; // Available immediately
            } else if (candidateDays <= 7) {
                return 80; // Available within a week
            } else if (candidateDays <= 15) {
                return 60; // Available within 15 days
            } else if (candidateDays <= 30) {
                return 40; // Available within a month
            } else {
                return 20; // More than a month
            }
        } else {
            // Job has specific notice period preference
            if (candidateDays <= jobPreferredDays) {
                // Candidate can join within or earlier than preferred period
                if (candidateDays == 0 && jobPreferredDays > 0) {
                    return 95; // Available immediately when job can wait
                }
                return 100; // Perfect match or earlier
            } else {
                // Candidate needs more time
                Decimal ratio = (Decimal)jobPreferredDays / candidateDays;
                return (ratio * 100).setScale(2);
            }
        }
    }

    /* =======================
       HELPER: Parse Notice Period
    ======================== */
    private static Integer parseNoticePeriodToDays(String noticePeriod) {
        if (String.isBlank(noticePeriod)) return 0;
        
        String notice = noticePeriod.toLowerCase().trim();
        
        if (notice.contains('immediate') || notice.contains('now') || 
            notice.contains('available') || notice.contains('serving') ||
            notice.contains('0 day') || notice.contains('0 days')) {
            return 0;
        }
        
        // Try to extract number
        Pattern digitPattern = Pattern.compile('(\\d+)');
        Matcher digitMatcher = digitPattern.matcher(notice);
        
        if (digitMatcher.find()) {
            Integer daynumber = Integer.valueOf(digitMatcher.group(1));
            
            if (notice.contains('day') || notice.contains('days')) {
                return daynumber;
            } else if (notice.contains('week') || notice.contains('weeks')) {
                return daynumber * 7;
            } else if (notice.contains('month') || notice.contains('months')) {
                return daynumber * 30;
            }
        }
        
        return 30; // Default assumption
    }

    /* =========================================================
       UPDATED WRAPPER CLASS WITH PERCENTAGE BREAKDOWN
    ========================================================= */
    public class CandidateWrapper implements Comparable {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public Decimal matchPercentage;
        @AuraEnabled public String candidateRating;
        @AuraEnabled public String primarySkills;
        @AuraEnabled public Decimal totalExperience;
        @AuraEnabled public Decimal relevantExperience;
        @AuraEnabled public String currentLocation;
        @AuraEnabled public String preferredLocation;
        @AuraEnabled public String noticePeriod;
        @AuraEnabled public Date lastProfileUpdate;
        @AuraEnabled public Datetime lastUpdateDatetime;
        
        // Match percentage breakdown (nullable for missing data)
        @AuraEnabled public Decimal skillMatchPercentage;
        @AuraEnabled public Decimal experienceMatchPercentage;
        @AuraEnabled public Decimal locationMatchPercentage;
        @AuraEnabled public Decimal availabilityMatchPercentage;
        
        // For sorting
        private Integer ratingWeight;

        public CandidateWrapper(
            Candidate__c c,
            Set<String> matchedSkillSet,
            Decimal totalMatchPercentage,
            Decimal skillMatchPercentage,
            Decimal experienceMatchPercentage,
            Decimal locationMatchPercentage,
            Decimal availabilityMatchPercentage
        ) {
            this.candidateId = c.Id;
            this.candidateName = c.Name;
            this.matchPercentage = totalMatchPercentage;
            this.candidateRating = String.isBlank(c.Rating__c) ? 'Not Rated' : c.Rating__c;
            this.primarySkills = c.Skills__c;
            this.totalExperience = c.Total_Experience__c;
            this.relevantExperience = c.Relevant_Experience__c;
            this.currentLocation = c.Current_Location__c;
            this.preferredLocation = c.Preferred_Location__c;
            this.noticePeriod = c.Notice_Period__c;
            
            // Date only
            this.lastProfileUpdate = c.LastModifiedDate != null 
                ? c.LastModifiedDate.date() 
                : Date.today();
            
            // Datetime version
            this.lastUpdateDatetime = c.LastModifiedDate != null 
                ? c.LastModifiedDate 
                : Datetime.now();
            
            // Store match percentage breakdown
            this.skillMatchPercentage = skillMatchPercentage;
            this.experienceMatchPercentage = experienceMatchPercentage;
            this.locationMatchPercentage = locationMatchPercentage;
            this.availabilityMatchPercentage = availabilityMatchPercentage;
            
            // Calculate rating weight for sorting
            if (String.isBlank(c.Rating__c)) {
                this.ratingWeight = 0;
            } else {
                switch on c.Rating__c {
                    when 'Excellent' { this.ratingWeight = 5; }
                    when 'Good'      { this.ratingWeight = 4; }
                    when 'Average'   { this.ratingWeight = 3; }
                    when 'Poor'      { this.ratingWeight = 2; }
                    when 'Bad'       { this.ratingWeight = 1; }
                    when else        { this.ratingWeight = 0; }
                }
            }
        }

        public Integer compareTo(Object o) {
            CandidateWrapper other = (CandidateWrapper)o;
            
            // 1. Highest Match Percentage (descending)
            if (this.matchPercentage != other.matchPercentage) {
                return (other.matchPercentage > this.matchPercentage) ? 1 : -1;
            }
            
            // 2. Highest Candidate Rating (descending)
            if (this.ratingWeight != other.ratingWeight) {
                return other.ratingWeight - this.ratingWeight;
            }
            
            // 3. Most Recent Profile Update (descending)
            if (this.lastUpdateDatetime != other.lastUpdateDatetime) {
                return (other.lastUpdateDatetime > this.lastUpdateDatetime) ? 1 : -1;
            }
            
            return 0;
        }
    }

    /* =========================================================
       BULK CREATE INTERVIEWS
    ========================================================= */
    @AuraEnabled
    public static List<Id> createInterviewsBulk(Id jobPositionId, List<Id> candidateIds) {
        List<Interview__c> interviews = new List<Interview__c>();
        
        for (Id candidateId : candidateIds) {
            interviews.add(new Interview__c(
                Job_Position__c = jobPositionId,
                Candidate__c = candidateId
            ));
        }
        
       try {

    // ✅ CRUD CHECK
    if (!Schema.sObjectType.Interview__c.isCreateable()) {
        throw new AuraHandledException('You do not have permission to create Interview records.');
    }

    insert interviews;

    List<Id> interviewIds = new List<Id>();
    for (Interview__c iv : interviews) {
        interviewIds.add(iv.Id);
    }
    return interviewIds;

} catch (DmlException dmlex) {
    throw new AuraHandledException(dmlex.getDmlMessage(0));
} catch (Exception ex) {
    throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
}

    }

    /* =========================================================
       CREATE SINGLE INTERVIEW
    ========================================================= */
    @AuraEnabled
public static Id createInterview(Id jobPositionId, Id candidateId) {
    try {

        // ✅ CRUD CHECK (PMD satisfied)
        if (!Schema.sObjectType.Interview__c.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create Interview records.'
            );
        }

        Interview__c interview = new Interview__c(
            Job_Position__c = jobPositionId,
            Candidate__c    = candidateId
        );

        insert interview;
        return interview.Id;

    } catch (DmlException dmlex) {
        throw new AuraHandledException(dmlex.getDmlMessage(0));
    } catch (Exception ex) {
        throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
    }
}

}