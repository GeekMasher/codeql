(function(){
    function $Injected1(name){}
    $Injected1.$inject = ['name'];
    angular.module('app1').controller('controller1', $Injected1);

    function $Injected2(name){} // $ Alert
    $Injected2.$inject = ['name'];
    angular.module('app2').controller('controller2', ['name', $Injected2]);

    function $Injected3(name){} // $ Alert
    $Injected3.$inject = ['name'];
    $Injected3.$inject = ['name'];
    angular.module('app3').controller('controller3', $Injected3);

    function not$Injected4(name){}
    angular.module('app4').controller('controller4', not$Injected4);
    function not$Injected5(name){}
    angular.module('app5').controller('controller5', ['name', not$Injected5]);

    function $Injected6(name){} // OK - because it never becomes registered
    $Injected6.$inject = ['name'];
    $Injected6.$inject = ['name'];

    function not$Injected7(name){}
    angular.module('app7').controller('controller7', ['name', not$Injected7]);
    angular.module('app7').controller('controller7', ['name', not$Injected7]);
    angular.module('app7').controller('controller7', not$Injected7);

    angular.module('app8').controller('controller8', function inline8(name){});

    angular.module('app9').controller('controller9', ['name', function inline9(name){}]);

    function $Injected10(name){ // $ Alert - alert formatting for multi-line function
    }
    $Injected10.$inject = ['name'];
    angular.module('app10').controller('controller10', ['name', $Injected10]);

})();
