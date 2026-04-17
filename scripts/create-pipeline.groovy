import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.UserRemoteConfig
import com.cloudbees.plugins.credentials.CredentialsProvider

def jenkins = Jenkins.instance
def jobName = 'mayavi-pipeline'

// Check if credentials exist
def credentialsId = 'github-credentials'
def credentials = CredentialsProvider.lookupCredentials(
    com.cloudbees.plugins.credentials.Credentials.class,
    jenkins,
    null,
    null
).find { it.id == credentialsId }

if (credentials == null) {
    println "ERROR: Credential '${credentialsId}' not found!"
    println "Available credentials:"
    CredentialsProvider.lookupCredentials(
        com.cloudbees.plugins.credentials.Credentials.class,
        jenkins,
        null,
        null
    ).each { println "  - ${it.id}" }
    return
}

println "Found credential: ${credentialsId}"

// Delete existing job if present
def existingJob = jenkins.getItemByFullName(jobName)
if (existingJob != null) {
    println "Deleting existing job: ${jobName}"
    existingJob.delete()
}

// Create new pipeline job
println "Creating job: ${jobName}"
def job = jenkins.createProject(WorkflowJob.class, jobName)

// Configure Git SCM
def remoteConfig = new UserRemoteConfig(
    'https://github.com/xinshu-cmu-S25/mayavi.git',
    null,
    null,
    credentialsId
)

def scm = new GitSCM(
    [remoteConfig],
    [new BranchSpec('*/main')],
    false,
    [],
    null,
    null,
    []
)

// Set pipeline definition from SCM
def flowDefinition = new CpsScmFlowDefinition(scm, "Jenkinsfile")
flowDefinition.setLightweight(true)
job.setDefinition(flowDefinition)

// Add GitHub webhook trigger (if plugin available)
try {
    def trigger = new com.cloudbees.jenkins.GitHubPushTrigger()
    job.addTrigger(trigger)
    println "Added GitHub Push trigger"
} catch (Exception e) {
    println "WARNING: Could not add GitHub Push trigger (plugin may not be installed): ${e.message}"
}

// Save and schedule initial build
job.save()
println "Job saved successfully"

job.scheduleBuild2(0)
println "Successfully created ${jobName} and scheduled initial build"