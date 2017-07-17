import React from 'react';
import axios from 'axios';

class RandomNumberComponent extends React.Component {

    constructor(props) {
        super(props);
        this.state = { rand: 0 };
        this.onRand = this.onRand.bind(this);
    }

    componentDidMount(){
        this.onRand();
    }

    onRand() {
        axios.get('/api/index.cfm/rand').then(response => { this.setState({ rand: response.data.rand }); });
    }

    render() {
        return (
            <div>
                Random Number: <span>{this.state.rand}</span>
                <div><button onClick={this.onRand}>New Random Number</button></div>
            </div>
        );
    }

}

export default RandomNumberComponent;