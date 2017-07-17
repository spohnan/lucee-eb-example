component extends="taffy.core.resource" taffy_uri="/rand" {

    function get(){
        return rep( { "rand": RandRange(1, 1000) } );
    }

}