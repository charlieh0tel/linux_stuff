{
    printf("  {\n");
    printf("     \"name\": \"%s\",\n", $2);
    printf("     \"mac_addr\": [\"%s\"]\n", $1);
    printf("  }\n");
}
