process TIMESTAMP {
    container = 'docker.io/jdj0303/bigbacter-base:1.0.0'

    output:
    stdout

    when:
    task.ext.when == null || task.ext.when

    shell:
    """
    date +%s | tr -d '\n\t\r '
    """
}
