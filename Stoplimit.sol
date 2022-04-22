// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./UniswapV2Router02.sol";

contract StopLimit is Ownable {
    uint256 public orderAmount;
    address public executorAddress;
    uint256 public orderFee;
    UniswapV2Router02 pancackeV2Router;

    mapping (address => Order[]) public OrdersForAddress;
    mapping (uint256 => Order) public HashForOrder;

    enum Status {
        waiting,
        executed,
        canceled,
        finished
    }

    struct Order {
        address[] exchangePairPath;
        uint256 executionPrice; // price to be paid by buyer
        uint256 amount;
        address orderOwner;
        Status state;
    }
    Order[] public orders;

    


    constructor(uint256 _orderFee, address _executorAddr) {
        orderFee = _orderFee.div(10 ** 3).mul(1 ether); // 0.009 BNB
        executorAddress = _executorAddr;

        pancackeV2Router = UniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
    }

    function createOrder(
        address[] calldata _exPairPath,
        uint256 _amount,
        uint256 _exPrice
    ) external payable {
        require(msg.value >= orderFee, "not enough fee");
        Order[] memory _orders = OrdersForAddress[msg.sender];
        _orders.push(
            Order(
                _exPairPath,
                _amount,
                _exPrice,
                msg.sender,
                Status.waiting
            )
        );
        OrdersForAddress[msg.sender] = _orders;

        uint256 currentAllowance = IERC20(_exPairPath[0]).allowance(
            msg.sender,
            address(this)
        );
        require(currentAllowance >= _amount, "not enough allowance");
        IERC20(_exPairPath[0]).transferFrom(msg.sender, address(this), _amount);
    }

    function cancelOrder(uint256 index) external {
        Order[] memory _orders = OrdersForAddress[msg.sender];
        require(_orders.length > 0, "Not created order");
        // require(orders[index].orderOwner == msg.sender, "no permission");
        require(_orders[index].state != Status.canceled, "Already canceld");
        _orders[index].state = Status.canceled;

        OrdersForAddress[msg.sender] = _orders;
    }

    function setExecutorAddress(address _addr) external onlyOwner {
        executorAddress = _addr;
    }

    function setOrderFee(uint256 _fee) external onlyOwner {
        orderFee = _fee.div(10 ** 3).mul(1 ether);
    }

    function _getTotalAmount(address owner, address[] memory _exchangePairPath)
        internal
        returns (uint256)
    {
        uint256 totalAmount = 0;
        Order[] memory _orders = OrdersForAddress[owner];
        for (uint256 i = 0; i < _orders.length; i++) {
            if (_orders[i].state == Status.waiting) {
                if (
                    _orders[i].exchangePairPath[0] == _exchangePairPath[0] &&
                    _orders[i].exchangePairPath[1] == _exchangePairPath[1]
                ) {
                    totalAmount = totalAmount.add(_orders[i].amount);
                    _orders[i].state = Status.executed;
                }
            }
        }
        return totalAmount;
    }

    function executeOrder(address[] calldata _exchangePairPath) external {
        require(msg.sender == executorAddress, "no permission");
        uint256 totalAmount = _getTotalAmount(msg.sender, _exchangePairPath);
        require(totalAmount >= orderAmount, "not reached order amount");

        uint256[] memory amounts = pancackeV2Router.swapExactTokensForTokens(totalAmount, 0, _exchangePairPath, address(this), block.timestamp);

        Order[] memory _orders = OrdersForAddress[msg.sender];
        for(uint i = 0; i < _orders.length; i ++) {
            if (_orders[i].state == Status.executed) {
                uint amount = amounts[0].mul(_orders[i].amount).div(totalAmount);
                _orders[i].state = Status.finished;
                IERC20(_exchangePairPath[1]).transfer(_orders[i].orderOwner, amount);
            }
        }
    }

    function withDraw() public onlyOwner {
        require(address(this).balance > 0, "no balance");
        payable(msg.sender).transfer(address(this).balance);
    }

    //@dev function to receive money to provide the users the buyback values
    receive() external payable {}
}