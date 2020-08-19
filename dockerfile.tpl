# Builder
{% for p in platforms -%}
FROM --platform={{ p.key }} {{ builder.image }} as builder

RUN {{ builder.script }}

COPY rootfs/ /dist/
{%- if target.fix_symlink %}
RUN mv /dist/bin/* /dist/usr/bin/ && rm -rf /dist/bin
{%- end if %}

{% end for -%}

# Target image
FROM {{ target.image }}
COPY --from=builder /dist/ /
ENTRYPOINT [ "/init" ]
CMD []
