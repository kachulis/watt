version 1.0

workflow say_hello {
    input {
        Array[String] lines
        Boolean compress
    }

    call Announce {
        input:
            lines=lines,
            compress=compress
    }

    output {
        File announcement = Announce.announcement
    }
}

task Announce {
    input {
        Array[String] lines
        Boolean compress
    }

    command <<<
        for line in "~{sep= '" "' lines}"
        do
            echo $line >> announcement.txt
        done

        if ~{compress}; then
            gzip announcement.txt
        fi
    >>>

    output {
        File announcement = if compress then "announcement.txt.gz" else "announcement.txt"
    }
}