component extends="taffy.core.resource" taffy_uri="/version" {

    function get(){
        return rep( { "version": "0.0.4-SNAPSHOT" } );
    }

}