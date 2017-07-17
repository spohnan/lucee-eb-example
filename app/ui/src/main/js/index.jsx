import React from 'react';
import {render} from 'react-dom';
import RandomNumberComponent from "./RandomNumberComponent.jsx";

class App extends React.Component {
    render () {
        return (
            <div>
                <p>Lucee API Example</p>
                <RandomNumberComponent />
            </div>
        );
    }
}

render(<App/>, document.getElementById('app'));
