// SPDX-License-Identifier: MIT
// Define la licencia del código fuente como MIT.

pragma solidity >=0.8.0 <0.9.0;
// Especifica la versión de Solidity que debe ser utilizada, entre la versión 0.8.0 (inclusive) y la versión 0.9.0 (exclusiva).

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Importa los contratos IERC20 y SafeMath de la biblioteca de OpenZeppelin. IERC20 define una interfaz para trabajar con tokens ERC20, y SafeMath proporciona funciones matemáticas seguras para evitar desbordamientos.

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 */
// Documentación del contrato que define sus autores y su propósito.

contract DEX {
	/* ========== GLOBAL VARIABLES ========== */
	using SafeMath for uint256; // Utiliza la biblioteca SafeMath para todas las operaciones con uint256.
	IERC20 token; // Declara una variable 'token' del tipo IERC20 para interactuar con tokens ERC20.

	uint256 public totalLiquidity;
	mapping(address => uint256) public liquidity;
	// Declara una variable pública 'totalLiquidity' y un mapeo 'liquidity' para rastrear la liquidez proporcionada por cada dirección.

	/* ========== EVENTS ========== */
	// Eventos que serán emitidos por funciones para informar sobre las transacciones realizadas.
	event EthToTokenSwap(address, string, uint256, uint256);
	event TokenToEthSwap(address, string, uint256, uint256);
	event LiquidityProvided(address, uint256, uint256, uint256);
	event LiquidityRemoved(address, uint256, uint256, uint256);

	/* ========== CONSTRUCTOR ========== */
	// El constructor se ejecuta una sola vez al desplegar el contrato.
	constructor(address token_addr) {
		token = IERC20(token_addr); // Inicializa la variable 'token' con la dirección del token ERC20 proporcionada.
	}

	/* ========== MUTATIVE FUNCTIONS ========== */
	// Funciones que cambian el estado del contrato.

	function init(uint256 _tokens) public payable returns (uint256) {
		// Función para inicializar la liquidez del contrato. Se deben enviar ETH y tokens al llamar a esta función.
		require(totalLiquidity == 0, "DEX: init - already has liquidity");
		// Requiere que no haya liquidez previamente para proceder.
		totalLiquidity = address(this).balance;
		// Establece 'totalLiquidity' al balance de ETH del contrato.
		liquidity[msg.sender] = totalLiquidity;
		// Asigna toda la liquidez inicial al usuario que llama la función.
		require(
			token.transferFrom(msg.sender, address(this), _tokens),
			"DEX: init - transfer did not transact"
		);
		// Transfiere los tokens del usuario al contrato y verifica que la transacción haya sido exitosa.
		return totalLiquidity;
		// Retorna la liquidez total del contrato.
	}

	function price(
		uint256 xInput,
		uint256 xReserves,
		uint256 yReserves
	) public pure returns (uint256 yOutput) {
		// Función para calcular el precio de un activo en función de las reservas actuales en el contrato y la cantidad de entrada.
		uint256 xInputWithFee = xInput.mul(997);
		uint256 numerator = xInputWithFee.mul(yReserves);
		uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
		return (numerator / denominator);
		// Retorna la cantidad de salida del activo después de aplicar la fórmula del modelo de mercado automático (AMM).
	}

	function getLiquidity(address lp) public view returns (uint256) {
		// Función para obtener la liquidez de un proveedor específico usando su dirección.
		return liquidity[lp];
		// Retorna la cantidad de liquidez que el proveedor ha depositado en el contrato.
	}

	function ethToToken() public payable returns (uint256 tokenOutput) {
		// Función que permite a los usuarios intercambiar ETH por tokens.
		require(msg.value > 0, "cannot swap 0 ETH");
		// Verifica que el usuario haya enviado ETH con la transacción.
		uint256 ethReserve = address(this).balance.sub(msg.value);
		uint256 token_reserve = token.balanceOf(address(this));
		// Calcula las reservas de ETH y tokens después de recibir el ETH.
		tokenOutput = price(msg.value, ethReserve, token_reserve);
		// Calcula la cantidad de tokens que el usuario recibirá por su ETH.

		require(
			token.transfer(msg.sender, tokenOutput),
			"ethToToken(): reverted swap."
		);
		// Realiza la transferencia de tokens al usuario y verifica que la transacción haya sido exitosa.
		emit EthToTokenSwap(
			msg.sender,
			"Eth to Balloons",
			msg.value,
			tokenOutput
		);
		// Emite un evento con los detalles del intercambio.
		return tokenOutput;
		// Retorna la cantidad de tokens transferidos al usuario.
	}

	function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
		// Función que permite a los usuarios intercambiar tokens por ETH.
		require(tokenInput > 0, "cannot swap 0 tokens");
		// Verifica que el usuario haya enviado tokens con la transacción.
		uint256 token_reserve = token.balanceOf(address(this));
		ethOutput = price(tokenInput, token_reserve, address(this).balance);
		// Calcula la cantidad de ETH que el usuario recibirá por sus tokens.

		require(
			token.transferFrom(msg.sender, address(this), tokenInput),
			"tokenToEth(): reverted swap."
		);
		// Realiza la transferencia de tokens del usuario al contrato y verifica que la transacción haya sido exitosa.
		(bool sent, ) = msg.sender.call{ value: ethOutput }("");
		require(sent, "tokenToEth: revert in transferring eth to you!");
		// Envía el ETH al usuario y verifica que la transferencia haya sido exitosa.
		emit TokenToEthSwap(
			msg.sender,
			"Balloons to ETH",
			ethOutput,
			tokenInput
		);
		// Emite un evento con los detalles del intercambio.
		return ethOutput;
		// Retorna la cantidad de ETH transferida al usuario.
	}

	function deposit() public payable returns (uint256 tokensDeposited) {
		// Función para que los usuarios depositen ETH y tokens en la piscina de liquidez.
		require(msg.value > 0, "Must send value when depositing");
		// Verifica que el usuario haya enviado ETH con la transacción.
		uint256 ethReserve = address(this).balance.sub(msg.value);
		uint256 tokenReserve = token.balanceOf(address(this));
		// Calcula las reservas de ETH y tokens después de recibir el ETH.

		uint256 tokenDeposit = (msg.value.mul(tokenReserve) / ethReserve).add(
			1
		);
		// Calcula la cantidad de tokens que el usuario debe depositar, basándose en la cantidad de ETH enviado.
		uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;
		// Calcula la cantidad de tokens de liquidez que serán creados y proporcionados al usuario.
		liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
		totalLiquidity = totalLiquidity.add(liquidityMinted);
		// Actualiza la liquidez total del contrato y la liquidez específica del usuario.

		require(token.transferFrom(msg.sender, address(this), tokenDeposit));
		// Solicita los tokens del usuario y los transfiere al contrato.
		emit LiquidityProvided(
			msg.sender,
			liquidityMinted,
			msg.value,
			tokenDeposit
		);
		// Emite un evento con los detalles del depósito.
		return tokenDeposit;
		// Retorna la cantidad de tokens depositados por el usuario.
	}

	function withdraw(
		uint256 amount
	) public returns (uint256 eth_amount, uint256 token_amount) {
		// Función que permite a los usuarios retirar sus ETH y tokens de la piscina de liquidez.
		require(
			liquidity[msg.sender] >= amount,
			"withdraw: sender does not have enough liquidity to withdraw."
		);
		// Verifica que el usuario tenga suficiente liquidez para retirar la cantidad deseada.
		uint256 ethReserve = address(this).balance;
		uint256 tokenReserve = token.balanceOf(address(this));
		// Obtiene las reservas actuales de ETH y tokens en el contrato.

		uint256 ethWithdrawn = amount.mul(ethReserve) / totalLiquidity;
		uint256 tokenAmount = amount.mul(tokenReserve) / totalLiquidity;
		// Calcula la cantidad de ETH y tokens que el usuario puede retirar, basado en su participación en la liquidez.
		liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
		totalLiquidity = totalLiquidity.sub(amount);
		// Actualiza la liquidez total del contrato y la liquidez específica del usuario.

		(bool sent, ) = payable(msg.sender).call{ value: ethWithdrawn }("");
		require(sent, "withdraw(): revert in transferring eth to you!");
		// Envía el ETH al usuario y verifica que la transferencia haya sido exitosa.
		require(token.transfer(msg.sender, tokenAmount));
		// Envía los tokens al usuario y verifica que la transferencia haya sido exitosa.
		emit LiquidityRemoved(msg.sender, amount, ethWithdrawn, tokenAmount);
		// Emite un evento con los detalles del retiro.
		return (ethWithdrawn, tokenAmount);
		// Retorna las cantidades de ETH y tokens retirados.
	}
}
