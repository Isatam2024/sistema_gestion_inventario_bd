CREATE DATABASE sistema_gestion_inventario;

USE sistema_gestion_inventario;

CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    estado ENUM('activo', 'inactivo') DEFAULT 'activo', 
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO productos (nombre, descripcion, precio, estado) VALUES
('Producto A', 'Descripción del Producto A', 50.00, 'activo'),
('Producto B', 'Descripción del Producto B', 75.50, 'activo'),
('Producto C', 'Descripción del Producto C', 150.00, 'activo'),
('Producto D', 'Descripción del Producto D', 200.00, 'inactivo'),
('Producto A', 'Descripción de Producto A', 50.00, 'activo');


CREATE TABLE stock (
    id_stock INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    fecha_ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('activo', 'inactivo') DEFAULT 'activo',
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO stock (id_producto, cantidad, estado) VALUES
(1, 50, 'activo'),
(2, 30, 'activo'),
(3, 10, 'activo'),
(4, 0, 'inactivo'),
(1, 5, 'activo');


CREATE TABLE ventas (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metodo_pago ENUM('efectivo', 'tarjeta', 'transferencia') NOT NULL,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO ventas (id_producto, cantidad, total, metodo_pago) VALUES
(1, 2, 100.00, 'efectivo'),
(2, 1, 75.50, 'tarjeta'),
(3, 5, 750.00, 'transferencia');


CREATE TABLE historial_stock (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    cantidad_cambiada INT NOT NULL,
    tipo_cambio ENUM('venta', 'compra', 'ajuste') NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO historial_stock (id_producto, cantidad_cambiada, tipo_cambio) VALUES
(1, -2, 'venta'),
(2, -1, 'venta'),
(3, -5, 'venta'),
(4, 0, 'ajuste');

CREATE TABLE informe_ventas (
    id_venta INT NOT NULL,
    producto VARCHAR(255) NOT NULL,
    cantidad_vendida INT NOT NULL,
    total_ventas DECIMAL(10, 2) NOT NULL,
    fecha_venta DATE NOT NULL,
    metodo_pago ENUM('efectivo', 'tarjeta', 'transferencia') NOT NULL,
    numero_ventas INT NOT NULL,
    PRIMARY KEY (id_venta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


INSERT INTO informe_ventas (id_venta, producto, cantidad_vendida, total_ventas, fecha_venta, metodo_pago, numero_ventas) VALUES
(1, 'Producto A', 2, 100.00, '2024-11-20', 'efectivo', 1),
(2, 'Producto B', 1, 75.50, '2024-11-21', 'tarjeta', 1),
(3, 'Producto C', 5, 750.00, '2024-11-22', 'transferencia', 1);

CREATE TABLE alertas_inventario (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT NOT NULL,
    mensaje VARCHAR(255),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE alertas_stock (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_producto INT,
    mensaje VARCHAR(255),
    fecha_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);


CREATE TABLE reporte_ventas_semanal (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    total_ventas DECIMAL(10, 2) NOT NULL,
    cantidad_vendida INT NOT NULL,
    cantidad_ventas INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


DELIMITER //

CREATE TRIGGER alertar_bajo_inventario
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
    -- Comprobar si el stock actualizado es menor que 10
    IF NEW.cantidad < 10 THEN
        -- Registrar la alerta en la tabla
        INSERT INTO alertas_inventario (id_producto, mensaje)
        VALUES (
            NEW.id_producto,
            CONCAT('Alerta: El producto "', 
                   (SELECT nombre FROM productos WHERE id_producto = NEW.id_producto),
                   '" tiene bajo inventario. Stock actual: ', NEW.cantidad)
        );
    END IF;
END //

DELIMITER ;




-- Actualizar el stock para simular una venta o disminución
UPDATE stock SET cantidad = 4 WHERE id_producto = 1;  -- Producto A ahora tendrá 4 unidades


-- El siguiente TRIGGER Registra cambios en el stock tras cada transacción.

USE sistema_gestion_inventario;


DELIMITER //

CREATE TRIGGER after_venta_insert
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    -- Declarar variable local para el stock actual
    DECLARE nueva_cantidad INT DEFAULT 0;

    -- Verificar y actualizar el stock
    SELECT cantidad INTO nueva_cantidad
    FROM stock
    WHERE id_producto = NEW.id_producto
    AND estado = 'activo'
    ORDER BY fecha_ultima_actualizacion DESC
    LIMIT 1;

    -- Si hay suficiente stock, actualizarlo
    IF nueva_cantidad >= NEW.cantidad THEN
        UPDATE stock
        SET cantidad = cantidad - NEW.cantidad,
            fecha_ultima_actualizacion = CURRENT_TIMESTAMP
        WHERE id_producto = NEW.id_producto
        AND estado = 'activo'
        ORDER BY fecha_ultima_actualizacion DESC
        LIMIT 1;

        -- Registrar en el historial de stock
        INSERT INTO historial_stock (id_producto, cantidad_cambiada, tipo_cambio)
        VALUES (NEW.id_producto, -NEW.cantidad, 'venta');
    ELSE
        INSERT INTO historial_stock (id_producto, cantidad_cambiada, tipo_cambio)
        VALUES (NEW.id_producto, 0, 'ajuste');
    END IF;
END;




DELIMITER ;

-- Para verificar este funcionamiento vamos a insertar una venta en la tabla
INSERT INTO ventas (id_producto, cantidad, total, metodo_pago)
VALUES (1, 2, 100.00, 'efectivo');

-- Despues revisar si el stock del producto se rebajo

SELECT * FROM stock WHERE id_producto = 1;

-- verificar si se cambio en la tabla de historial_stock
SELECT * FROM historial_stock WHERE id_producto = 1 ORDER BY fecha DESC;

-- vamos a insertar una venta que exceda el stock disponible
INSERT INTO ventas (id_producto, cantidad, total, metodo_pago)
VALUES (1, 100, 5000.00, 'tarjeta');

SHOW TRIGGERS;


-- Ahora vamos a crear un TRIGGER Para Actualizar automáticamente el estado de productos (activo/inactivo) según la disponibilidad.

DELIMITER //

CREATE TRIGGER actualizar_estado_producto
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
    DECLARE total_stock INT;

    -- Calcular el total del stock para el producto actualizado
    SELECT SUM(cantidad) INTO total_stock
    FROM stock
    WHERE id_producto = NEW.id_producto AND estado = 'activo';

    -- Actualizar el estado del producto dependiendo del stock total
    IF total_stock <= 0 THEN
        UPDATE productos
        SET estado = 'inactivo'
        WHERE id_producto = NEW.id_producto;
    ELSE
        UPDATE productos
        SET estado = 'activo'
        WHERE id_producto = NEW.id_producto;
    END IF;
END;
//

DELIMITER ;

-- Verificacion de TRIGGER

-- Primero actualizamos el stock

UPDATE stock
SET cantidad = 0
WHERE id_stock = 2;

-- verificamos el estado del producto atraves de una consulta
SELECT id_producto, nombre, estado FROM productos WHERE id_producto = 2;


-- Se puede evidenciar que el Producto B sale inactivo poruq no posee stock


-- Stored Procedures

-- El primero es Agregar nuevos productos al inventario.

DELIMITER //

CREATE PROCEDURE agregar_producto(
    IN p_nombre VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10, 2),
    IN p_cantidad_stock INT,
    IN p_estado_producto ENUM('activo', 'inactivo')
)
BEGIN
    DECLARE nuevo_id_producto INT;
    
    -- Insertar el producto en la tabla productos
    INSERT INTO productos (nombre, descripcion, precio, estado)
    VALUES (p_nombre, p_descripcion, p_precio, p_estado_producto);
    
    -- Obtener el id del nuevo producto insertado
    SET nuevo_id_producto = LAST_INSERT_ID();
    
    -- Insertar el stock inicial para el nuevo producto
    INSERT INTO stock (id_producto, cantidad, estado)
    VALUES (nuevo_id_producto, p_cantidad_stock, p_estado_producto);
    
END //

DELIMITER ;


-- Para verificar que este bien

-- hacemos la llamada del stored procedure

CALL agregar_producto('Nuevo Producto', 'Descripción del nuevo producto', 100.00, 50, 'activo');

-- y hacemos la consulta para ver si se ve la modificacion
SELECT * FROM productos;
SELECT * FROM stock;

-- Nos damos cuenta que funciona

-- El siguiente es Actualizar información de productos existentes.


DELIMITER //

CREATE PROCEDURE actualizar_producto(
    IN p_id_producto INT,
    IN p_nombre VARCHAR(255),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10, 2),
    IN p_estado_producto ENUM('activo', 'inactivo')
)
BEGIN
    -- Actualizar la información del producto en la tabla productos
    UPDATE productos
    SET nombre = p_nombre,
        descripcion = p_descripcion,
        precio = p_precio,
        estado = p_estado_producto
    WHERE id_producto = p_id_producto;
    
END //

DELIMITER ;

-- Para verificar si funciona llamamos el proceso

CALL actualizar_producto(1, 'Producto A Modificado', 'Descripción modificada', 120.00, 'activo');

-- consultemos para ver si se actualizo

SELECT * FROM productos WHERE id_producto = 1;

-- se evidencia que funciono 

-- El siguiente es Procesar ventas y ajustar el stock.

DELIMITER //

CREATE PROCEDURE procesar_venta(
    IN p_id_producto INT, 
    IN p_cantidad INT, 
    IN p_metodo_pago ENUM('efectivo', 'tarjeta', 'transferencia'), 
    OUT mensaje_error VARCHAR(255)
)
BEGIN
    DECLARE p_precio DECIMAL(10, 2);
    DECLARE p_stock INT;

    -- Inicializar mensaje de error
    SET mensaje_error = '';

    -- Obtener el precio del producto
    SELECT precio INTO p_precio 
    FROM productos 
    WHERE id_producto = p_id_producto;

    -- Verificar que el producto existe
    IF p_precio IS NULL THEN
        SET mensaje_error = 'Producto no encontrado.';
    ELSE
        -- Verificar si hay suficiente stock
        SELECT cantidad INTO p_stock
        FROM stock
        WHERE id_producto = p_id_producto;

        IF p_stock < p_cantidad THEN
            SET mensaje_error = 'No hay suficiente stock para procesar la venta.';
        ELSE
            -- Actualizar el stock
            UPDATE stock 
            SET cantidad = cantidad - p_cantidad 
            WHERE id_producto = p_id_producto;

            -- Insertar la venta
            INSERT INTO ventas (id_producto, cantidad, total, metodo_pago) 
            VALUES (p_id_producto, p_cantidad, p_precio * p_cantidad, p_metodo_pago);

            -- Registrar el cambio en el historial de stock
            INSERT INTO historial_stock (id_producto, cantidad_cambiada, tipo_cambio) 
            VALUES (p_id_producto, -p_cantidad, 'venta');

            -- Mensaje final de éxito
            SET mensaje_error = 'Venta procesada correctamente.';
        END IF;
    END IF;

END //

DELIMITER ;


-- para verificar llamamos el procedimiento
SET @mensaje_error = '';
CALL procesar_venta(1, 5, 'efectivo', @mensaje_error);
SELECT @mensaje_error;


-- revisamos el resultado de ventas
SELECT * FROM ventas WHERE id_producto = 1;

-- verificamos stock

SELECT * FROM stock WHERE id_producto = 1;

-- verificamos historial
SELECT * FROM historial_stock WHERE id_producto = 1;

-- se observa que se hizo y registro procedimiento de venta


-- El siguiente stored procedure es Generar reportes de stock y ventas.

DELIMITER //

CREATE PROCEDURE generar_reporte_stock_ventas()
BEGIN
    -- Reporte de Stock
    SELECT p.id_producto, p.nombre, s.cantidad AS stock_actual
    FROM productos p
    LEFT JOIN stock s ON p.id_producto = s.id_producto
    WHERE s.estado = 'activo' AND p.estado = 'activo'
    ORDER BY p.nombre;

    -- Reporte de Ventas
    SELECT p.id_producto, p.nombre, SUM(v.cantidad) AS cantidad_vendida, SUM(v.total) AS total_ventas
    FROM productos p
    LEFT JOIN ventas v ON p.id_producto = v.id_producto
    GROUP BY p.id_producto
    HAVING cantidad_vendida > 0
    ORDER BY p.nombre;

END //

DELIMITER ;

-- vamos a verificar si funciona,primero inserto datos nuevos de productos

INSERT INTO productos (nombre, descripcion, precio, estado) 
VALUES 
('Producto X', 'Descripción del Producto X', 100.00, 'activo'),
('Producto Y', 'Descripción del Producto Y', 200.00, 'activo');

-- inserto datos en ventas

INSERT INTO ventas (id_producto, cantidad, total, metodo_pago) 
VALUES 
(1, 5, 500.00, 'efectivo'),
(2, 3, 600.00, 'tarjeta');

-- luego llamo procedimiento

CALL generar_reporte_stock_ventas();

-- observamos que funciona ya que vemos reportes de cambios en stock y ventas

-- EVENTS

-- Verificación diaria de productos con bajo inventario


SET GLOBAL event_scheduler = ON;

DELIMITER //

CREATE EVENT verificacion_bajo_inventario
ON SCHEDULE EVERY 1 DAY -- Se ejecuta cada día
DO
BEGIN
    -- Declarar las variables necesarias
    DECLARE v_id_producto INT;
    DECLARE v_nombre VARCHAR(255);
    DECLARE v_cantidad INT;
    
    -- Declarar la variable de control para el cursor
    DECLARE done INT DEFAULT 0;

    -- Declarar el cursor
    DECLARE cur CURSOR FOR 
    SELECT p.id_producto, p.nombre, s.cantidad
    FROM productos p
    JOIN stock s ON p.id_producto = s.id_producto
    WHERE s.cantidad < 10 AND s.estado = 'activo' AND p.estado = 'activo';

    -- Declarar la condición de manejo de errores
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Abrir el cursor
    OPEN cur;

    -- Leer las filas del cursor
    read_loop: LOOP
        FETCH cur INTO v_id_producto, v_nombre, v_cantidad;
        
        -- Verificar si se llegó al final del cursor
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Insertar los datos en la tabla alertas_stock
        INSERT INTO alertas_stock (id_producto, mensaje, fecha_alerta)
        VALUES (v_id_producto, CONCAT('Alerta: El producto "', v_nombre, '" tiene bajo inventario. Stock actual: ', v_cantidad), NOW());
    END LOOP;

    -- Cerrar el cursor
    CLOSE cur;


END //

DELIMITER ;

-- Para verificarsi se creo ejecuta esto

SHOW EVENTS;

-- observaras que ha sido creado

ALTER EVENT verificacion_bajo_inventario ENABLE;

-- En la tabla alertas_stock observaras productos con menos de 10 unidades

SELECT * FROM alertas_stock WHERE id_producto = 5;

-- El sigueinte evento es Generación semanal de reportes de ventas.

DELIMITER //

CREATE EVENT generacion_reportes_ventas
ON SCHEDULE EVERY 1 WEEK -- Se ejecuta cada semana
STARTS '2024-12-01 00:00:00' -- El primer evento será el 1 de diciembre de 2024 (ajusta la fecha según necesites)
DO
BEGIN
    -- Insertar un reporte con las ventas de la semana en la tabla de reportes
    INSERT INTO reporte_ventas_semanal (fecha_inicio, fecha_fin, total_ventas, cantidad_vendida, cantidad_ventas)
    SELECT 
        -- Fecha de inicio de la semana (lunes)
        DATE_SUB(CURDATE(), INTERVAL (DAYOFWEEK(CURDATE()) - 1) DAY) AS fecha_inicio,
        
        -- Fecha de fin de la semana (domingo)
        DATE_ADD(CURDATE(), INTERVAL (7 - DAYOFWEEK(CURDATE())) DAY) AS fecha_fin,
        
        -- Total de ventas de la semana
        SUM(v.total) AS total_ventas,
        
        -- Total de productos vendidos
        SUM(v.cantidad) AS cantidad_vendida,
        
        -- Número de ventas realizadas
        COUNT(v.id_venta) AS cantidad_ventas
    FROM ventas v
    WHERE v.fecha >= DATE_SUB(CURDATE(), INTERVAL (DAYOFWEEK(CURDATE()) - 1) DAY)  -- Filtro por semana (desde el lunes)
    AND v.fecha <= DATE_ADD(CURDATE(), INTERVAL (7 - DAYOFWEEK(CURDATE())) DAY)  -- Filtro por semana (hasta el domingo)
    GROUP BY fecha_inicio, fecha_fin;
END//

DELIMITER ;

-- Para verificar que el evento esta bien mira si aparece en eventos con 
SHOW EVENTS;

-- en este se observa que esta creado,despues de una semana vera el resporte de ventas en la tabla correspondiente

SELECT * FROM reporte_ventas_semanal;


-- El siguiente evento es Limpieza mensual de registros de productos obsoletos,es decir que esten inactivos o durante los ultimos 6 meses no registren compras

DELIMITER //

CREATE EVENT limpieza_mensual_productos_obsoletos
ON SCHEDULE EVERY 1 MONTH -- El evento se ejecuta una vez al mes
STARTS '2024-12-01 00:00:00'  -- Puedes ajustar la fecha de inicio del evento
DO
BEGIN
    -- Eliminar productos inactivos que no tienen ventas en los últimos 6 meses
    DELETE p
    FROM productos p
    LEFT JOIN ventas v ON p.id_producto = v.id_producto
    WHERE p.estado = 'inactivo'  -- Producto inactivo
    AND (v.fecha IS NULL OR v.fecha < DATE_SUB(CURDATE(), INTERVAL 6 MONTH));  -- Sin ventas en los últimos 6 meses o sin ventas

    -- También se puede incluir la eliminación de registros en la tabla de stock
    DELETE s
    FROM stock s
    WHERE s.id_producto NOT IN (SELECT id_producto FROM productos WHERE estado = 'activo');
END//

DELIMITER ;

-- para verificar que se creo mira eventos,este evento se ejecuta una vez al mes

SHOW EVENTS;



