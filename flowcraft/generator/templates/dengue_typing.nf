getRef_{{ pid }} = params.reference{{ param_id}} ? "true" : "false"
checkpointReferenceGenome_{{ pid }} = Channel.value(getRef_{{ pid }})

checkpointReferenceGenome_{{ pid }}.into{ reference_reads_{{ pid }} ; reference_assembly_{{ pid }} }

midChan = Channel.create()

{{ input_channel }}.join(_LAST_fastq_{{ pid }}, ).set{ midChan }


class VerifyCompletnessTyping {

    public static boolean contigs(String filename, int threshold){
        BufferedReader reader = new BufferedReader(new FileReader(filename));
        boolean result = processContigs(reader, threshold);
        reader.close()

        return result;
    }

    private static boolean processContigs(BufferedReader reader, int threshold){
        String line;
        int lineThreshold = 0;
        List splittedLine

        while ((line = reader.readLine()) != null) {
            if (line.startsWith('>')) {
                splittedLine = line.split('_')
                lineThreshold = splittedLine[3].toInteger()
                if(lineThreshold >= threshold) {
                    return true;
                }
             }
        }

        return false;
    }
}


type_reads_{{ pid }} = Channel.create()
type_assembly_{{ pid }} = Channel.create()
midChan.choice(type_assembly_{{ pid }}, type_reads_{{ pid }}){a -> a[1].toString() == "null" ? false : VerifyCompletnessTyping.contigs(a[1].toString(), 10000) == true ? 0 : 1}


process dengue_typing_assembly_{{ pid }} {

    // Send POST request to platform
    {% include "post.txt" ignore missing %}

    tag { sample_id }

    publishDir "results/dengue_typing/${sample_id}/"


    input:
    set sample_id, file(assembly), file(fastq_pair) from type_assembly_{{ pid }}
    val reference from reference_assembly_{{ pid }}

    output:
    file "seq_typing*"
    set sample_id, file(assembly) into out_typing_assembly_{{ pid }}
    file("*.fa") optional true into _ref_seqTyping_assembly_{{ pid }}
    {% with task_name="dengue_typing_assembly" %}
    {%- include "compiler_channels.txt" ignore missing -%}
    {% endwith %}

    script:
    template "dengue_typing_assembly.py"

}


process dengue_typing_reads_{{ pid }} {

// Send POST request to platform
    {% include "post.txt" ignore missing %}

    tag { sample_id }

    publishDir "results/dengue_typing/${sample_id}/"


    input:
    set sample_id, file(assembly), file(fastq_pair) from type_reads_{{ pid }}
    val reference from reference_reads_{{ pid }}

    output:
    file "seq_typing*"
    set sample_id, file("*_consensus.fasta") into out_typing_reads_{{ pid }}
    file("*.fa") optional true into _ref_seqTyping_reads_{{ pid }}
    {% with task_name="dengue_typing_reads" %}
    {%- include "compiler_channels.txt" ignore missing -%}
    {% endwith %}

    script:
    template "dengue_typing_reads.py"

}

out_typing_assembly_{{ pid }}.mix(out_typing_reads_{{ pid }}).into{ {{ output_channel }} }

_ref_seqTyping_assembly_{{ pid }}.mix(_ref_seqTyping_reads_{{ pid }}).into{ _ref_seqTyping_{{ pid }} }

{{ forks }}

