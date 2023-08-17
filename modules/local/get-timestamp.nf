process TIMESTAMP {
    container = 'ubuntu:jammy'

    output:
    stdout

    when:
    task.ext.when == null || task.ext.when

    shell:
    """
    date +%s | tr -d '\n\t\r '
    """
}
