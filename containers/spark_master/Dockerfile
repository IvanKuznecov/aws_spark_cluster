FROM bitnami/spark:latest

# Switch to root to modify permissions
USER root

# Copy custom spark-defaults.conf to the appropriate directory
COPY spark-defaults.conf /opt/bitnami/spark/conf/spark-defaults.conf

# Ensure proper permissions
RUN chmod 644 /opt/bitnami/spark/conf/spark-defaults.conf

# Optional: Recreate symbolic links if needed
# RUN ln -sf /opt/bitnami/spark/conf/spark-defaults.conf /bitnami/spark/conf/spark-defaults.conf
