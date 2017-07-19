component extends="taffy.core.resource" taffy_uri="/version" {

    function get(){
        return rep( { "version": "${project.parent.version}" } );
    }

}